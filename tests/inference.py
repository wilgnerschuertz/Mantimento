"""Run one installed model offline; invoke under a network-denying sandbox."""
import json
import os
import sys
from mlx_lm import load, generate
from mlx_lm.sample_utils import make_sampler
model_id = sys.argv[1]
model, tokenizer = load(model_id)
prompt = tokenizer.apply_chat_template([{'role':'user','content':'Responda em português em uma frase: quanto é 2 + 2?'}], tokenize=False, add_generation_prompt=True, enable_thinking=False)
answer = generate(model, tokenizer, prompt=prompt, max_tokens=64, sampler=make_sampler(temp=0), verbose=False)
print(json.dumps({'model':model_id,'answer':answer,'offline':os.environ.get('HF_HUB_OFFLINE')},ensure_ascii=False))
assert '4' in answer or 'quatro' in answer.lower(), 'Resposta aritmética inesperada'
