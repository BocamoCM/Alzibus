import os
from PIL import Image

icon_path = 'assets/icon/app_icon_foreground.png'

if not os.path.exists(icon_path):
    print("Error: No se encuentra " + icon_path)
    exit(1)

# Abrimos la imagen original
img = Image.open(icon_path).convert("RGBA")
width, height = img.size

# Reducimos el logo al 65% para crear el "Safe Zone" de Android
new_w = int(width * 0.65)
new_h = int(height * 0.65)
img_resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)

# Creamos un lienzo transparente del tamaño original
new_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))

# Pegamos el logo más pequeño justo en el centro
offset_x = (width - new_w) // 2
offset_y = (height - new_h) // 2
new_img.paste(img_resized, (offset_x, offset_y), img_resized)

# Sobrescribimos el archivo
new_img.save(icon_path)
print("¡Icono rescaleado y centrado con éxito!")
