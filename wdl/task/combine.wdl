version 1.1

import "global_config.wdl"

task GLnexus {
    input {
        Array[File] all_vcfs
        Array[File] all_tbis
        String output_dir
        String batch_name
    }

    File gvcf_list = write_lines(all_vcfs)

    runtime {
        backend: "Local"
        singularity: "glnexus_v1.4.1.sif"
    }

    command <<<
        #!/bin/bash
        mkdir -p ~{output_dir}/04.combine
        cp ~{gvcf_list} ~{output_dir}/~{batch_name}/04.combine/gvcf.list
        echo 'GLnexus analysis start'
        glnexus_cli --dir /tempdir/GLnexus.DB \
            --config gatk \
            --threads 80 \
            --list ~{gvcf_list} > ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_GenotypeGVCFs.g.bcf
        rm -rf ~{output_dir}/~{batch_name}/04.combine/tmp
        echo 'GLnexus analysis end'
    >>>

    output {
        File gvcf_bcf_file = "~{output_dir}/~{batch_name}/04.combine/~{batch_name}_GenotypeGVCFs.g.bcf"
    }
}

task combine_gvcfs {
    input {
        Config cfg
        File input_bcf_file
        String output_dir
        String batch_name
    }

    File bcftools = cfg.bcftools
    File bgzip = cfg.bgzip
    File py = cfg.py
    File chr_list = cfg.chr_list
    File fai = cfg.fai
    File Rscript = cfg.Rscript
    File snp_stat = cfg.snp_stat
    File parallel = cfg.parallel
    File popSNP_SNPStat = cfg.popSNP_SNPStat

    runtime {
        backend: "Local"
    }

    command <<<
        #!/bin/bash
        mkdir -p ~{output_dir}/~{batch_name}/04.combine
        echo 'get rawSNP vcf result'
        \time -v ~{bcftools} view -V indels --threads 40 ~{input_bcf_file} | ~{bgzip} -@ 40 -c > ~{output_dir}/~{batch_name}/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawSNP.pre.vcf.gz
        echo 'rawSNP vcf result step is finished!'

        echo 'get rawInDel vcf result'
        \time -v ~{bcftools} view -V snps --threads 40 ~{input_bcf_file} | ~{bgzip} -@ 40 -c > ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawINDEL.pre.vcf.gz
        echo 'rawInDel vcf result step is finished!'

        echo 'snp_stat.py start'
        \time -v ~{py} ~{snp_stat} ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawSNP.pre.vcf.gz ~{fai} ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_rawVariants.SNP.density 20000
        grep -w -f ~{chr_list} ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_rawVariants.SNP.density > ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_plot_rawVariants.SNP.density
        echo 'snp_stat.py end'

        echo 'rawVariants.SNP.density'
        grep -w -f ~{chr_list} ~{fai} > ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_plot_ref.fai
        \time -v ~{Rscript} ~{popSNP_SNPStat} ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_rawVariants.SNP.density SNP.density/rawVariants.SNP.density.pdf ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_plot_ref.fai
        echo 'Finish rawVariants.SNP.density step'

        echo 'Deal the half_all of SNP vcf Start!'
        \time -v ~{bcftools} +fill-tags --threads 20 ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawSNP.pre.vcf.gz | ~{parallel} -k --pipe --block 20M  sed -r 's#\\./\([0-9]\)#0/\\1#g' | ~{bgzip} -@20 > ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawSNP.vcf.gz
        echo 'Deal the half_all of SNP vcf End!'

        echo 'Deal the half_all of INDEL vcf Start!'
        \time -v ~{bcftools} +fill-tags --threads 20 ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawINDEL.pre.vcf.gz | ~{parallel} -k --pipe --block 20M sed -r 's#\\./\([0-9]\)#0/\\1#g' | ~{bgzip} -@20 > ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawINDEL.vcf.gz
        echo 'Deal the half_all of INDEL vcf End!'

        \time -v ~{bcftools} stats ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawSNP.vcf.gz > ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawSNP.vcf.stat
        \time -v ~{bcftools} stats ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawINDEL.vcf.gz > ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawINDEL.vcf.stat
    >>>

    output {
        File combine_gvcf_snp = "~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawSNP.vcf.gz"
        File combine_gvcf_indel = "~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawINDEL.vcf.gz"
        File gvcf_stat_snp = "~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawSNP.vcf.stat"
        File gvcf_stat_indel = "~{output_dir}/~{batch_name}/04.combine/~{batch_name}_CombineGVCFs_GenotypeGVCFs.rawINDEL.vcf.stat"
    }
}