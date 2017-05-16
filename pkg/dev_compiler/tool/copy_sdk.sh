# Hacky script to copy the files over from the main
# distribution. Isn't there something that does this already?
set -e -x
cp ../../sdk/lib/html/dart2js/html_dart2js.dart tool/input_sdk/lib/html/dart2js
cp ../../sdk/lib/indexed_db/dart2js/indexed_db_dart2js.dart tool/input_sdk/lib/indexed_db/dart2js
cp ../../sdk/lib/svg/dart2js/svg_dart2js.dart tool/input_sdk/lib/svg/dart2js
cp ../../sdk/lib/web_audio/dart2js/web_audio_dart2js.dart tool/input_sdk/lib/web_audio/dart2js
cp ../../sdk/lib/web_gl/dart2js/web_gl_dart2js.dart tool/input_sdk/lib/web_gl/dart2js
cp ../../sdk/lib/web_sql/dart2js/web_sql_dart2js.dart tool/input_sdk/lib/web_sql/dart2js
