version 1.1

task align_only {
    input {
        File clean_r1
        File clean_r2
        File ref
        String sample_name
        String batch_name
        String output_dir
        Array[Int] gpu_group  
    }

    runtime {
        cpu: 1
        image: "parabricks.4.6.sif"
        cuda_visible_devices: sep(",", gpu_group)
    }

    command <<<
        #!/bin/bash
        set -euo pipefail
        GPU_CSV="~{sep=',' gpu_group}"
        NUM_GPUS="$(awk -F',' '{print NF}' <<< "${GPU_CSV}")"
        mkdir -p ~{output_dir}/~{batch_name}/02.bam
        #fq2bam
        pbrun fq2bam \
            --ref ~{ref} \
            --in-fq ~{clean_r1} ~{clean_r2} \
            "@RG\\tID:~{sample_name}\\tLB:~{sample_name}\\tPL:~{sample_name}\\tSM:~{sample_name}\\tPU:~{sample_name}" \
            --out-bam ~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam \
            --align-only --num-gpus "${NUM_GPUS}"        
    >>>

    output {
        File out_bam = "~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam"
        #File out_bai = "~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam.bai"
    }
}

workflow align_only_wf {
    input {
        File sample_info
        File ref
        String batch_name
        String output_dir
        Array[Array[Int]] gpu_ids
    }

    Map[String, Array[File]] sample_info_map = read_json(sample_info)
    Array[String] key_samples = keys(sample_info_map)
    scatter(sample_idx in range(length(key_samples))) {
        String sample = key_samples[sample_idx]
        Int gpu_idx = sample_idx - (length(gpu_ids) * floor((sample_idx + 0.0) / length(gpu_ids)))
        call align_only {
            input:
                clean_r1 = sample_info_map[sample][0],
                clean_r2 = sample_info_map[sample][1],
                ref = ref,
                sample_name = sample,
                batch_name = batch_name,
                output_dir = output_dir,
                gpu_group = gpu_ids[gpu_idx]
        }
    }

    output {
        Array[File] all_bams = align_only.out_bam 
        #Array[File] all_bais = align_only.out_bai 
    }
}
