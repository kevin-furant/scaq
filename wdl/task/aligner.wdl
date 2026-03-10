version 1.1

import "global_config.wdl"

task sample_aligner {
    input {
        Config cfg
        File clean_r1
        File clean_r2
        String sample_name
        String batch_name
        String output_dir
        Array[Int] gpu_group
    }

    File ref = cfg.ref
    File samtools = cfg.samtools

    runtime {
        backend: "Local"
        container: "parabricks.4.6.sif"
    }

    command <<<
        #!/bin/bash
        export SINGULARITYENV_CUDA_VISIBLE_DEVICES=~{sep=',' gpu_group}
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
            ~{output_dir}/02.bam/~{sample_name}.bam > ~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam.stat
    >>>

    output {
        String sample = sample_name
        File out_bam = "~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam"
        File out_bai = "~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam.bai"
        File bam_stat = "~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam.stat"
    }
}


workflow aligner_workflow {
    input {
        Config cfg
        File? sample_info
        String batch_name
        String output_dir
        Array[String]? samples
        Array[File]? all_clean_r1
        Array[File]? all_clean_r2
        Array[Array[Int]] gpu_ids
    }

    if (!defined(sample_info)){

        Array[String] samples_selected = select_first([samples])
        Array[File] all_clean_r1_selected = select_first([all_clean_r1])
        Array[File] all_clean_r2_selected = select_first([all_clean_r2])
        Array[Pair[File, File]] pair_reads = zip(all_clean_r1_selected, all_clean_r2_selected)
        Map[String, Pair[File, File]] sample_reads_map = as_map(zip(samples_selected, pair_reads))
        Map[String, Array[Int]] sample_gpu_groups_1 = as_map(cross(samples_selected, gpu_ids))

        scatter(sample in samples_selected){
            call sample_aligner as flow_sample_aligner {
                input:
                    cfg = cfg,
                    clean_r1 = sample_reads_map[sample].left,
                    clean_r2 = sample_reads_map[sample].right,
                    sample_name = sample,
                    batch_name = batch_name,
                    output_dir = output_dir,
                    gpu_group = sample_gpu_groups_1[sample]
            }
        }
    }

    if (defined(sample_info)){

        File sample_info_selected = select_first([sample_info])
        Map[String, Array[File]] sample_info_map = read_json(sample_info_selected)
        Array[String] key_samples = keys(sample_info_map)
        Map[String, Array[Int]] sample_gpu_groups_2 = as_map(cross(key_samples, gpu_ids))

        scatter(sample in key_samples){
            call sample_aligner as start_sample_aligner {
                input:
                    cfg = cfg,
                    sample_name = sample,
                    clean_r1 = sample_info_map[sample][0],
                    clean_r2 = sample_info_map[sample][1],
                    batch_name = batch_name,
                    output_dir = output_dir,
                    gpu_group = sample_gpu_groups_2[sample]
            }
        }
    }

    output {
        Array[File]? all_bams = if (defined(sample_info)) then start_sample_aligner.out_bam else flow_sample_aligner.out_bam
        Array[File]? all_bais = if (defined(sample_info)) then start_sample_aligner.out_bai else flow_sample_aligner.out_bai
        Array[File]? all_bam_stats = if (defined(sample_info)) then start_sample_aligner.bam_stat else flow_sample_aligner.bam_stat
        Array[String]? sample_names = if (defined(sample_info)) then key_samples else samples_selected
    }
}