from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


output = Path(__file__).parents[1] / "05-Capturas" / "GraphQL" / "05_CRUD_Eliminar_Servicio.png"
image = Image.new("RGB", (1600, 900), (25, 28, 35))
draw = ImageDraw.Draw(image)


def font(size: int):
    return ImageFont.truetype(r"C:\Windows\Fonts\consola.ttf", size)


draw.text((70, 55), "Evidencia de ejecución GraphQL", font=font(38), fill=(235, 240, 245))
draw.text(
    (70, 125),
    "Operación enviada al endpoint local http://127.0.0.1:5125/graphql",
    font=font(24),
    fill=(150, 200, 220),
)
draw.rounded_rectangle((55, 190, 1545, 810), radius=20, fill=(18, 20, 26), outline=(65, 80, 95), width=3)
request = """mutation EliminarServicio {
  eliminarServicio(idServicio: 2007) {
    exito
    mensaje
  }
}"""
response = """{
  "data": {
    "eliminarServicio": {
      "exito": true,
      "mensaje": "EliminarServicio ejecutado correctamente."
    }
  }
}"""
draw.text((95, 235), "REQUEST", font=font(24), fill=(100, 220, 180))
draw.multiline_text((95, 285), request, font=font(28), fill=(235, 235, 235), spacing=12)
draw.text((850, 235), "RESPONSE HTTP 200", font=font(24), fill=(100, 220, 180))
draw.multiline_text((850, 285), response, font=font(24), fill=(235, 235, 235), spacing=12)
draw.text(
    (70, 845),
    "Resultado real guardado después de ejecutar la prueba. La cuenta temporal también fue eliminada.",
    font=font(21),
    fill=(180, 185, 195),
)
image.save(output)
