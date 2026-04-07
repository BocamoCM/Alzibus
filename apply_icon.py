import shutil

src = r"C:\Users\borji\.gemini\antigravity\brain\3ab5dd31-82a9-4ff6-bb3e-f0fce9bea290\alzibus_logo_v3_1774986608577.png"
app_icon = r"c:\Users\borji\Alzibus\assets\icon\app_icon.png"
foreground = r"c:\Users\borji\Alzibus\assets\icon\app_icon_foreground.png"

shutil.copyfile(src, app_icon)
shutil.copyfile(src, foreground)
print("Icono copiado correctamente.")
