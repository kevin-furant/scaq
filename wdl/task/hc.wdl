version 1.1

import "global_config.wdl"

task sample_hc {
    input {
        Config cfg
        String sample_name
        File input_bam
        File input_bai
        String output_dir
        String batch_name
        Array[Int] gpu_group
    }

    File ref = cfg.ref

    runtime {
        backend: "Local"
        container: "parabricks.4.3.sif"
    }

    command <<<
        #!/bin/bash
        export SINGULARITYENV_CUDA_VISIBLE_DEVICES=~{sep=',' gpu_group}
        mkdir -p ~{output_dir}/~{batch_name}/03.vcf

        pbrun haplotypecaller \
            --ref ~{ref} \
            --in-bam ~{input_bam} \
            --out-variants ~{output_dir}/~{batch_name}/03.vcf/~{sample_name}.HP.g.vcf.gz \
            --gvcf \
            -num-gpus 2
    >>>

    output {
        File out_vcf = "~{output_dir}/~{batch_name}/03.vcf/~{sample_name}.HP.g.vcf.gz"
        File out_tbi = "~{output_dir}/~{batch_name}/03.vcf/~{sample_name}.HP.g.vcf.gz.tbi"
    }
}

workflow hc_workflow {
    input {
        Config cfg
        File? sample_info
        String output_dir
        String batch_name
        Array[String]? input_samples
        Array[File]? all_bams
        Array[File]? all_bais
        Array[Array[Int]] gpu_ids
    }

    if (defined(sample_info)){
        #如果只做hc,那就得提供数据路径信息json 文件格式 sample\tbam_path
        File sample_info_file = select_first([sample_info])
        Map[String, File] sample_info_map = read_json(sample_info_file)
        Array[String] samples = keys(sample_info_map)
        Map[String, Array[Int]] sample_gpu_groups_1 = as_map(cross(samples, gpu_ids))
        scatter(sample in samples){
            call sample_hc as start_sample_hc {
                input:
                    cfg = cfg,
                    sample_name = sample,
                    input_bam = sample_info_map[sample],
                    output_dir = output_dir,
                    batch_name = batch_name,
                    gpu_group = sample_gpu_groups_1[sample]
            }
        }
    }

    if(!defined(sample_info)){
        Array[String] input_samples_selected = select_first([input_samples])
        Array[File] all_bams_selected = select_first([all_bams])
        Array[File] all_bais_selected = select_first([all_bais])
        Map[String, File] sample_bam_map = as_map(zip(input_samples_selected, all_bams_selected))
        Map[String, File] sample_bai_map = as_map(zip(input_samples_selected, all_bais_selected))
        Map[String, Array[Int]] sample_gpu_groups_2 = as_map(cross(input_samples_selected, gpu_ids))
        scatter(sample in input_samples_selected){
            call sample_hc as flow_sample_hc {
                input:
                    cfg = cfg,
                    sample_name = sample,
                    input_bam = sample_bam_map[sample],
                    input_bai = sample_bai_map[sample],
                    output_dir = output_dir,
                    batch_name = batch_name,
                    gpu_group = sample_gpu_groups_2[sample]
            }
        }
    }
    output {
        Array[File]? all_vcfs = if(defined(sample_info)) then start_sample_hc.out_vcf else flow_sample_hc.out_vcf
        Array[File]? all_tbis = if(defined(sample_info)) then start_sample_hc.out_tbi else flow_sample_hc.out_tbi
    }
}