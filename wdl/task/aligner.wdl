version 1.1

import "global_config.wdl"
    alias Config as Config

File samtools = Config.samtools

task sample_aligner {
    input {
        File ref
        File clean_r1
        File clean_r2
        String sample_name
        String batch_name
        String output_dir
        Array[Int] gpu_group
    }

    runtime {
        backend: "Local"
        container: "parabricks.4.6"
    }

    command <<<
        #!/bin/bash
        export SINGULARITYENV_CUDA_VISIBLE_DEVICES=~{sep=",", gpu_group}
        mkdir -p ~{output_dir}/~{batch_name}/02.bam
        #fq2bam
        pbrun fq2bam \
            --ref ~{ref} \
            --in-fq ~{clean_r1} ~{clean_r2} \
            "@RG\\tID:~{sample_name}\\tLB:~{sample_name}\\tPL:~{sample_name}\\tSM:~{sample_name}\\tPU:~{sample_name}" \
            --out-bam ~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam \
            --num-gpus 2
        #samtools stat
        samtools stat --coverage 1,30,1 -@ 20 \
            ~{output_dir}/02.bam/~{sample}.bam > ~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam.stat
    >>>

    output {
        File out_bam = "~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam"
        File bam_stat = "~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam.stat"
    }
}


workflow aligner_workflow {
    input {
        File ref
        String batch_name
        String output_dir
        Array[String] samples
        Array[File] all_clean_r1
        Array[File] all_clean_r2
        Array[Array[Int, Int]] gpu_ids
    }

    Array[Pair[File, File]] pair_reads = zip(all_clean_r1, all_clean_r2)
    Array[Pair[String, Pair[File, File]]] sample_pair_reads = zip(samples, pair_reads)
    Map[String, Pair[File, File]] sample_reads_map = as_map(sample_pair_reads)
    Array[Pair[String, Array[Int, Int]]] sample_gpu_groups = cross(samples, gpu_ids)

    scatter(sample in samples){
        call sample_aligner {
            input:
                ref = ref,
                clean_r1 = sample_reads_map[sample].left,
                clean_r2 = sample_reads_map[sample].right,
                sample_name = sample,
                input_float = 0.0
        }
    }
    output {
        File final_output = task_name.output_file
        String final_status = task_name.output_string
    }
}

