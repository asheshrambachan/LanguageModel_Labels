import s1_write_prompts
import s2_batch_prompt 
import s3_batch_status 
import s4_process_responses 
import s5_merge_returns 
import s6_common_sample 
from s0_constants import economic_questions, models, return_types, prompt_types


def run_pipeline():

    # print("Running s1...")
    # step1_write_prompts.main()  # Execute the main function in s1
    # print("Finished s1\n")
    
    # print("Running s2...")
    # step2_batch_prompt.main()  # Execute the main function in s2
    # print("Finished s1\n")

    for question in economic_questions[0:1]:
        for model in models[0:1]:
            for return_type in return_types[0:1]:

                # print("Running s4...")
                # s4_process_responses.main()  # Execute the main function in s4
                # print("Finished s4\n")
                
                # print("Running s5...")
                # s5_merge_returns.main()  # Execute the main function in s5
                # print("Finished s5\n")

                print("Running s6...")
                print(question, model, return_type)
                s6_common_sample.main(question=question, model=model, return_type=return_type) 

if __name__ == "__main__":
    run_pipeline()
