# Quita las capturas repetidas de la versión editable y las deja en orden.
#
# `fastlane shots` sube y luego verifica; si App Store Connect tarda en
# confirmar alguna, la vuelve a subir y queda duplicada (pasó con la 2.4.0:
# 6 capturas en es-ES, con voz y metas repetidas). Apple NO deja borrarlas una
# vez enviada la versión a revisión, así que esto se ejecuta siempre entre
# `fastlane shots` y el envío.
#
#   /Users/dani/.rbenv/versions/3.3.0/bin/ruby scripts/capturas_sin_duplicados.rb
require "spaceship"
require "json"

ORDEN = %w[
  mockup_01_voice.png
  mockup_02_chart.png
  mockup_03_goals.png
  mockup_04_home.png
].freeze

key = JSON.parse(File.read("fastlane/api_key.json"))
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: key["key_id"], issuer_id: key["issuer_id"], key: key["key"],
  is_key_content_base64: key["is_key_content_base64"] || false, in_house: false
)
app = Spaceship::ConnectAPI::App.find("com.idanidev.clarity")
ios = Spaceship::ConnectAPI::Platform::IOS
version = app.get_edit_app_store_version(platform: ios)
abort "no hay versión editable" unless version
estado = version.app_store_state
abort "la #{version.version_string} está en #{estado}: Apple ya no deja tocar las capturas" if
  %w[WAITING_FOR_REVIEW IN_REVIEW].include?(estado)

puts "versión #{version.version_string} (#{estado})"
version.get_app_store_version_localizations.each do |loc|
  loc.get_app_screenshot_sets.each do |set|
    vistos = {}
    set.app_screenshots.each do |captura|
      if vistos[captura.file_name]
        puts "#{loc.locale}: repetida, se borra #{captura.file_name}"
        Spaceship::ConnectAPI.delete_app_screenshot(app_screenshot_id: captura.id)
      else
        vistos[captura.file_name] = captura.id
      end
    end
    ids = ORDEN.map { |nombre| vistos[nombre] }.compact
    set.reorder_screenshots(app_screenshot_ids: ids) if ids.size == ORDEN.size
    puts "#{loc.locale}: #{ids.size} capturas#{ids.size == ORDEN.size ? ' en orden' : ' — REVISAR'}"
  end
end
