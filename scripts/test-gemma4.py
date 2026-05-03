from optimum.intel.openvino import OVModelForVisualCausalLM
from transformers import AutoProcessor

model_path = "/home/carlesra/Models/gemma-4-E4B-int4-ov"

print("Cargando processor...")
processor = AutoProcessor.from_pretrained(model_path)

print("Cargando modelo en CPU...")
model = OVModelForVisualCausalLM.from_pretrained(model_path)

print("Preparando prompt...")
messages = [
    {
        "role": "user",
        "content": [
            {"type": "text", "text": "Explica qué es la inteligencia artificial en 2 frases."}
        ]
    }
]

text = processor.apply_chat_template(messages, add_generation_prompt=True)
inputs = processor(text=text, return_tensors="pt")
input_len = inputs["input_ids"].shape[-1]

print("Generando respuesta...")
output = model.generate(**inputs, max_new_tokens=100, do_sample=False)
result = processor.decode(output[0][input_len:], skip_special_tokens=True)

print("\n--- Respuesta ---")
print(result)
