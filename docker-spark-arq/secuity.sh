keytool -genkeypair -keystore /opt/spark/.keystore \
-keyalg RSA -alias selfsigned \
-dname "CN=mysparkcert L=Arq S=BA C=AR" \
-storepass sparkarq2024 -keypass sparkarg2024key


keytool -exportcert -keystore /opt/spark/.keystore \
-alias selfsigned -storepass sparkarq2024 -file test1.cer

keytool -importcert -keystore /opt/spark/.truststore \
-alias selfsigned \
-storepass sparkarq2024 -file test1.cer -noprompt


spark.ssl.enabled                   true
spark.ssl.trustStore                /opt/spark/.truststore
spark.ssl.trustStorePassword        SparkArg202
spark.ssl.keyStore                  /opt/spark/.keystore
spark.ssl.keyStorePassword          SparkArg202
spark.ssl.keyPassword               sparkarg2024key
spark.ssl.protocol                  TLSv1.2
