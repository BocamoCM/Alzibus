import os
import shutil
from PIL import Image

input_path = r"C:\Users\borji\.gemini\antigravity\brain\3ab5dd31-82a9-4ff6-bb3e-f0fce9bea290\alzibus_flat_logo_1774985994820.png"
out_path = r"c:\Users\borji\Alzibus\assets\icon\app_icon_foreground.png"
app_icon_path = r"c:\Users\borji\Alzibus\assets\icon\app_icon.png"

# Copiamos la versión completa para usos en iOS o fallback (con fondo incluido)
shutil.copyfile(input_path, app_icon_path)

# Procesamos el fondo para dejar el icono flotando en PNG (necesario para Adaptive Icons en Android)
img = Image.open(input_path).convert("RGBA")
data = list(img.getdata())

# Cogemos el color del primer pixel (la esquina) asumiendo que es el fondo plano
bg_color = data[0]

new_data = []
for item in data:
    # Si el RGB del pixel se parece muchísimo al color de fondo, lo hacemos invisible (opacidad 0)
    diff_r = abs(item[0] - bg_color[0])
    diff_g = abs(item[1] - bg_color[1])
    diff_b = abs(item[2] - bg_color[2])
    
    if diff_r < 40 and diff_g < 40 and diff_b < 40:
        new_data.append((255, 255, 255, 0)) # Transparencia total
    else:
        new_data.append(item)

# Aplicar los pixeles y guardar
img.putdata(new_data)

# Vamos a reducirlo además un poco para que respire por los bordes
width, height = img.size
new_w = int(width * 0.70)
new_h = int(height * 0.70)
img_resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
final_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
offset_x = (width - new_w) // 2
offset_y = (height - new_h) // 2
final_img.paste(img_resized, (offset_x, offset_y), img_resized)

final_img.save(out_path)
print("¡Archivo PNG transparente generado con éxito y empaquetado!")
