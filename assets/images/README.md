# assets/images/

Practical 10 weather condition images. Drop the 6 PNG files from the Practical 10
materials here, named exactly:

- `sunny.png`        (Tiada hujan / clear)
- `cloudy.png`       (Berawan / cloudy)
- `haze.png`         (Berjerebu)
- `rainy.png`        (Hujan …)
- `thunderstorm.png` (Ribut petir …)
- `unknown.png`      (fallback when the forecast phrase is not recognised)

`forecast_list.dart` maps the Bahasa Malaysia forecast text to these filenames
(`_weatherStatus` map) and renders them with `Image.asset` at 48x48.
