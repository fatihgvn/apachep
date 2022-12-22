
if ! grep -q "IncludeOptional /usr/local/apachep/system/hosts/*.conf" /etc/apache2/apache2.conf; then
  echo "yeni satır eklendi"
	sed -i '/IncludeOptional\ mods\-enabled\/\*\.conf/a IncludeOptional /usr/local/apachep/system/hosts/*.conf' /etc/apache2/apache2.conf
else
  echo "zaten eklenmiş"
fi
