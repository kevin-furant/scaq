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
        cpu: 8
        image: "parabricks.4.6.sif"
        cuda_visible_devices: sep(",", gpu_group)
    }

    command <<<
        #!/bin/bash
        set -euo pipefail
        GPU_CSV="~{sep=',' gpu_group}"
        NUM_GPUS="$(awk -F',' '{print NF}' <<< "${GPU_CSV}")"
        MIN_FREE_PERCENT="${MIN_FREE_PERCENT:-90}"
        LOCK_ROOT="/tmp/cromwell-gpu-locks"
        LOCK_FILE="${LOCK_ROOT}/$(tr ',' '_' <<< "${GPU_CSV}").lock"
        export SINGULARITYENV_CUDA_VISIBLE_DEVICES="${GPU_CSV}"

        # Serialize jobs mapped to same GPU group to avoid check-then-run race.
        mkdir -p "${LOCK_ROOT}"
        exec 9>"${LOCK_FILE}"
        flock 9

        # Wait until target GPUs have no active compute process and enough free VRAM.
        wait_for_gpus_ready() {
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
                    local mem_pair free_mem total_mem free_percent
                    mem_pair="$(nvidia-smi --id="${gpu_id}" --query-gpu=memory.free,memory.total --format=csv,noheader,nounits 2>/dev/null | head -n 1)"
                    free_mem="$(awk -F',' '{gsub(/ /, "", $1); print $1}' <<< "${mem_pair}")"
                    total_mem="$(awk -F',' '{gsub(/ /, "", $2); print $2}' <<< "${mem_pair}")"
                    if [[ -z "${free_mem}" || -z "${total_mem}" || "${total_mem}" -eq 0 ]]; then
                        busy=1
                        break
                    fi
                    free_percent=$((100 * free_mem / total_mem))
                    if [[ "${free_percent}" -lt "${MIN_FREE_PERCENT}" ]]; then
                        busy=1
                        break
                    fi
                done
                if [[ "${busy}" -eq 0 ]]; then
                    echo "GPUs [${gpu_csv}] are ready (>=${MIN_FREE_PERCENT}% free VRAM). Start task."
                    return 0
                fi
                echo "GPUs [${gpu_csv}] are busy or low VRAM. Sleep ${sleep_seconds}s..."
                sleep "${sleep_seconds}"
            done
        }

        wait_for_gpus_ready "${GPU_CSV}" 10
        mkdir -p ~{output_dir}/~{batch_name}/02.bam
        #fq2bam
        pbrun fq2bam \
            --ref ~{ref} \
            --in-fq ~{clean_r1} ~{clean_r2} \
            "@RG\\tID:~{sample_name}\\tLB:~{sample_name}\\tPL:~{sample_name}\\tSM:~{sample_name}\\tPU:~{sample_name}" \
            --out-bam ~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam \
            --num-gpus "${NUM_GPUS}"
        #samtools stat
        samtools stat --coverage 1,30,1 -@ 20 \
            ~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam > ~{output_dir}/~{batch_name}/02.bam/~{sample_name}.bam.stat
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

        scatter(sample_idx in range(length(samples_selected))){
            String sample_1 = samples_selected[sample_idx]
            Int gpu_idx_1 = sample_idx - (length(gpu_ids) * floor((sample_idx + 0.0) / length(gpu_ids)))
            call sample_aligner as flow_sample_aligner {
                input:
                    cfg = cfg,
                    clean_r1 = sample_reads_map[sample_1].left,
                    clean_r2 = sample_reads_map[sample_1].right,
                    sample_name = sample_1,
                    batch_name = batch_name,
                    output_dir = output_dir,
                    # Rotate GPU groups when sample count exceeds gpu_ids count.
                    gpu_group = gpu_ids[gpu_idx_1]
            }
        }
    }

    if (defined(sample_info)){

        File sample_info_selected = select_first([sample_info])
        Map[String, Array[File]] sample_info_map = read_json(sample_info_selected)
        Array[String] key_samples = keys(sample_info_map)

        scatter(sample_idx in range(length(key_samples))){
            String sample_2 = key_samples[sample_idx]
            Int gpu_idx_2 = sample_idx - (length(gpu_ids) * floor((sample_idx + 0.0) / length(gpu_ids)))
            call sample_aligner as start_sample_aligner {
                input:
                    cfg = cfg,
                    sample_name = sample_2,
                    clean_r1 = sample_info_map[sample_2][0],
                    clean_r2 = sample_info_map[sample_2][1],
                    batch_name = batch_name,
                    output_dir = output_dir,
                    # Rotate GPU groups when sample count exceeds gpu_ids count.
                    gpu_group = gpu_ids[gpu_idx_2]
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