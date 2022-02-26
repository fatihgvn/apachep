## default folder permissions on bash

```
chown -R eve example.com/
chgrp -R www-data example.com/
chmod -R 750 example.com/
chmod g+s example.com/
```
