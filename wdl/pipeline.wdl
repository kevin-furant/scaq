version 1.1

#主workflow， subworkflow将会通过主workflow调用
workflow QCpipeline {
    inputs:
        File input_file
        String input_string = "default_value"

    call task_name {
        input:
            input_file = input_file,
            input_string = input_string,
            input_int = 1,
            input_float = 0.0
    }

    output {
        File final_output = task_name.output_file
        String final_status = task_name.output_string
    }
}

