import s1_write_prompts
import s2_batch_prompt 
import s3_batch_status 
import s4_process_responses 
import s5_merge_returns 
import s6_common_sample
import s7_batch_metrics
import s8_bad_responses
from s0_constants import economic_questions, models, return_types, prompt_types, years, month_batches

def run_pipeline():

    for question in economic_questions:
        for model in models:
            for month in month_batches:
                for year in years:
                    print("Running s4...")
                    s4_process_responses.main(question=question, model=model, month=month, year=year)  # Execute the main function in s4
                    print("Finished s4\n")

                    for return_type in return_types:
                        print("Running s5...")
                        s5_merge_returns.main(question=question, model=model, month=month, year=year, return_type=return_type)  # Execute the main function in s5
                        print("Finished s5\n")

    # Warning: This next loop takes roughly 25 minutes to run
    # 30 seconds per iteration x 5 questions x 3 models x 3 return types
    for question in economic_questions:
        for return_type in return_types:
            for model in models:
                print("Running s6...")
                print("question", question, model, return_type)
                s6_common_sample.save_common_sample_within(question=question, model=model, return_type=return_type) 
                print("Finished s6\n")
        
        s6_common_sample.save_common_sample_across(question, return_type)

    s7_batch_metrics.main()
    s8_bad_responses.main()

if __name__ == "__main__":
    run_pipeline()
