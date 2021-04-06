#!/bin/bash
MY_FILE="
	server {\n
        listen 8080;\n
        listen [::]:8080;\n
        root /www/staging/webapp;\n
        index index.html index.htm index.nginx-debian.html;\n
        server_name localhost;\n
        location / {\n
                try_files $uri $uri/ =404;\n
        }\n
}
"

echo $MY_FILE
