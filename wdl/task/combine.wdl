version 1.1

import "global_config.wdl"

task gatk_combine_gvcfs {
    input {
        Config cfg
        Array[File] all_vcfs
        Array[File] all_tbis
        String output_dir
        String batch_name
    }

    File gatk = cfg.gatk
    File ref = cfg.ref

    File vcf_list_file = write_lines(all_vcfs)

    runtime {
        cpu: 2
    }

    command <<<
        #!/bin/bash
        set -euo pipefail
        mkdir -p ~{output_dir}/~{batch_name}/04.combine
        cp ~{vcf_list_file} ~{output_dir}/~{batch_name}/04.combine/samples.gvcf.list
         ~{gatk} CombineGVCFs \
        -R ~{ref} \
        -o ~{output_dir}/~{batch_name}/04.combine/~{batch_name}_cohort.g.vcf.gz \
        -V ~{vcf_list_file} 
    >>>

    output {
        File cohort_vcf = "~{output_dir}/~{batch_name}/04.combine/~{batch_name}_cohort.g.vcf.gz"
    }
}