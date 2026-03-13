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
        cpu: 8
        image: "parabricks.4.3.sif"
    }

    command <<<
        #!/bin/bash
        set -euo pipefail
        GPU_CSV="~{sep=',' gpu_group}"
        export SINGULARITYENV_CUDA_VISIBLE_DEVICES="${GPU_CSV}"

        # Block until all target GPUs have no running compute process.
        wait_for_gpus_idle() {
            local gpu_csv="$1"
            local sleep_seconds="${2:-10}"
            IFS=',' read -r -a gpu_ids <<< "${gpu_csv}"
            while true; do
                local busy=0
                for gpu_id in "${gpu_ids[@]}"; do
                    local running_pids
                    running_pids="$(nvidia-smi --id="${gpu_id}" --query-compute-apps=pid --format=csv,noheader,nounits 2>/dev/null | awk '/^[0-9]+$/ {print}')"
                    if [[ -n "${running_pids}" ]]; then
                        busy=1
                        break
                    fi
                done
                if [[ "${busy}" -eq 0 ]]; then
                    echo "GPUs [${gpu_csv}] are idle. Start task."
                    return 0
                fi
                echo "GPUs [${gpu_csv}] are busy. Sleep ${sleep_seconds}s..."
                sleep "${sleep_seconds}"
            done
        }

        wait_for_gpus_idle "${GPU_CSV}" 10
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
        #如果只做hc,那就得提供数据路径信息json 文件格式 sample\tbam_path\tbai_path
        File sample_info_file = select_first([sample_info])
        Map[String, Array[File]] sample_info_map = read_json(sample_info_file)
        Array[String] samples = keys(sample_info_map)
        scatter(sample_idx in range(length(samples))){
            String sample_1 = samples[sample_idx]
            Int gpu_idx_1 = sample_idx - (length(gpu_ids) * floor((sample_idx + 0.0) / length(gpu_ids)))
            call sample_hc as start_sample_hc {
                input:
                    cfg = cfg,
                    sample_name = sample_1,
                    input_bam = sample_info_map[sample_1][0],
                    input_bai = sample_info_map[sample_1][1],
                    output_dir = output_dir,
                    batch_name = batch_name,
                    gpu_group = gpu_ids[gpu_idx_1]
            }
        }
    }

    if(!defined(sample_info)){
        Array[String] input_samples_selected = select_first([input_samples])
        Array[File] all_bams_selected = select_first([all_bams])
        Array[File] all_bais_selected = select_first([all_bais])
        Map[String, File] sample_bam_map = as_map(zip(input_samples_selected, all_bams_selected))
        Map[String, File] sample_bai_map = as_map(zip(input_samples_selected, all_bais_selected))
        scatter(sample_idx in range(length(input_samples_selected))){
            String sample_2 = input_samples_selected[sample_idx]
            Int gpu_idx_2 = sample_idx - (length(gpu_ids) * floor((sample_idx + 0.0) / length(gpu_ids)))
            call sample_hc as flow_sample_hc {
                input:
                    cfg = cfg,
                    sample_name = sample_2,
                    input_bam = sample_bam_map[sample_2],
                    input_bai = sample_bai_map[sample_2],
                    output_dir = output_dir,
                    batch_name = batch_name,
                    gpu_group = gpu_ids[gpu_idx_2]
            }
        }
    }
    output {
        Array[File]? all_vcfs = if(defined(sample_info)) then start_sample_hc.out_vcf else flow_sample_hc.out_vcf
        Array[File]? all_tbis = if(defined(sample_info)) then start_sample_hc.out_tbi else flow_sample_hc.out_tbi
    }
}