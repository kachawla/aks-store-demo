extension radius

param environment string

@description('Password for the RabbitMQ user the order pipeline authenticates with.')
@secure()
param rabbitMqPassword string

@description('Password/token for the OCI registry the containerImages recipe pushes to (a GitHub token with write:packages for ghcr.io).')
@secure()
param registryPassword string

@description('Username for the OCI registry the containerImages recipe pushes to (the GitHub actor for ghcr.io).')
@secure()
param registryUsername string

resource storeApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'aks-store-demo'
  properties: {
    environment: environment
  }
}

resource mongoDb 'Radius.Data/mongoDatabases@2025-08-01-preview' = {
  name: 'mongo'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/makeline-service/mongodb.go#L149'
    database: 'orderdb'
  }
}

resource rabbitMq 'Radius.Messaging/rabbitMQ@2025-08-01-preview' = {
  name: 'rabbitmq'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/order-service/plugins/messagequeue.js#L26'
    password: rabbitmqSecret.id
    queue: 'orders'
    username: 'myadmin'
  }
}

resource rabbitmqSecret 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'rabbitmq-secret'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/order-service/plugins/messagequeue.js#L29'
    data: {
      password: {
        value: rabbitMqPassword
      }
    }
  }
}

resource registryCreds 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'radius-ghcr-registry-creds'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: '.github/workflows/radius-verify-credentials.yml#L181'
    data: {
      password: {
        value: registryPassword
      }
      username: {
        value: registryUsername
      }
    }
  }
}

resource storeAdminNginxConfig 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'store-admin-nginx-config'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/store-admin/nginx.conf#L32'
    data: {
      'default.conf': {
        value: 'server {\n    listen       8081;\n    listen  [::]:8081;\n    server_name  localhost;\n\n    client_max_body_size 10m;\n\n    location / {\n        root   /usr/share/nginx/html;\n        index  index.html index.htm;\n        try_files $uri $uri/ /index.html;\n    }\n\n    error_page   500 502 503 504  /50x.html;\n    location = /50x.html {\n        root   /usr/share/nginx/html;\n    }\n\n    location /health {\n        default_type application/json;\n        return 200 \'{"status":"ok","version":"0.1.0"}\';\n    }\n\n    location ~ ^/api/makeline/order/(?<id>\\w+) {\n        proxy_pass http://${makelineService.properties.hosts.makeline}:3001/order/$id;\n        proxy_http_version 1.1;\n    }\n\n    location /api/makeline/order {\n        proxy_pass http://${makelineService.properties.hosts.makeline}:3001/order;\n        proxy_http_version 1.1;\n    }\n\n    location /api/makeline/order/fetch {\n        proxy_pass http://${makelineService.properties.hosts.makeline}:3001/order/fetch;\n        proxy_http_version 1.1;\n    }\n\n    location /api/order {\n        rewrite ^/api/order$ / break;\n        rewrite ^/api/order(/.*)$ $1 break;\n        proxy_pass http://${orderService.properties.hosts.order}:3000;\n        proxy_http_version 1.1;\n    }\n\n    location /api/products/ {\n        proxy_pass http://${productService.properties.hosts.product}:3002/;\n        proxy_http_version 1.1;\n    }\n\n    location /api/products {\n        rewrite ^/api/products$ / break;\n        rewrite ^/api/products(/.*)$ $1 break;\n        proxy_pass http://${productService.properties.hosts.product}:3002;\n        proxy_http_version 1.1;\n    }\n\n    location ~ ^/api/product/(?<id>\\w+) {\n        proxy_pass http://${productService.properties.hosts.product}:3002/$id;\n        proxy_http_version 1.1;\n    }\n\n    location /api/product {\n        rewrite ^/api/product$ / break;\n        rewrite ^/api/product(/.*)$ $1 break;\n        proxy_pass http://${productService.properties.hosts.product}:3002;\n        proxy_http_version 1.1;\n    }\n\n    location /api/product/ {\n        proxy_pass http://${productService.properties.hosts.product}:3002/;\n        proxy_http_version 1.1;\n    }\n\n    location /api/ai/health {\n        proxy_pass http://${productService.properties.hosts.product}:3002/ai/health;\n        proxy_http_version 1.1;\n    }\n\n    location /api/ai/generate/description {\n        proxy_pass http://${productService.properties.hosts.product}:3002/ai/generate/description;\n        proxy_http_version 1.1;\n    }\n\n    location /api/ai/generate/image {\n        proxy_pass http://${productService.properties.hosts.product}:3002/ai/generate/image;\n        proxy_http_version 1.1;\n        proxy_connect_timeout 30s;\n        proxy_read_timeout 300s;\n        proxy_send_timeout 300s;\n    }\n}\n'
      }
    }
  }
}

resource storeFrontNginxConfig 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'store-front-nginx-config'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/store-front/nginx.conf#L31'
    data: {
      'default.conf': {
        value: 'server {\n    listen       8080;\n    listen  [::]:8080;\n    server_name  localhost;\n\n    location / {\n        root   /usr/share/nginx/html;\n        index  index.html index.htm;\n        try_files $uri $uri/ /index.html;\n    }\n\n    error_page   500 502 503 504  /50x.html;\n    location = /50x.html {\n        root   /usr/share/nginx/html;\n    }\n\n    location /health {\n        default_type application/json;\n        return 200 \'{"status":"ok","version":"0.1.0"}\';\n    }\n\n    location /api/orders {\n        rewrite ^/api/orders$ / break;\n        rewrite ^/api/orders(/.*)$ $1 break;\n        proxy_pass http://${orderService.properties.hosts.order}:3000;\n        proxy_http_version 1.1;\n    }\n\n    location /api/products {\n        rewrite ^/api/products$ / break;\n        rewrite ^/api/products(/.*)$ $1 break;\n        proxy_pass http://${productService.properties.hosts.product}:3002;\n        proxy_http_version 1.1;\n    }\n}\n'
      }
    }
  }
}

resource makelineServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'makeline-service-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/makeline-service/Dockerfile'
    build: {
      platforms: [
        'linux/amd64'
      ]
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/makeline-service?ref=3c80efebd2889300a57f261803e79dad1e1ff611'
    }
    tag: '3c80efe'
  }
  dependsOn: [
    registryCreds
  ]
}

resource orderServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'order-service-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/order-service/Dockerfile'
    build: {
      platforms: [
        'linux/amd64'
      ]
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/order-service?ref=3c80efebd2889300a57f261803e79dad1e1ff611'
    }
    tag: '3c80efe'
  }
  dependsOn: [
    registryCreds
  ]
}

resource productServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'product-service-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/product-service/Dockerfile'
    build: {
      platforms: [
        'linux/amd64'
      ]
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/product-service?ref=3c80efebd2889300a57f261803e79dad1e1ff611'
    }
    tag: '3c80efe'
  }
  dependsOn: [
    registryCreds
  ]
}

resource storeAdminImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'store-admin-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/store-admin/Dockerfile'
    build: {
      platforms: [
        'linux/amd64'
      ]
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/store-admin?ref=3c80efebd2889300a57f261803e79dad1e1ff611'
    }
    tag: '3c80efe'
  }
  dependsOn: [
    registryCreds
  ]
}

resource storeFrontImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'store-front-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/store-front/Dockerfile'
    build: {
      platforms: [
        'linux/amd64'
      ]
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/store-front?ref=3c80efebd2889300a57f261803e79dad1e1ff611'
    }
    tag: '3c80efe'
  }
  dependsOn: [
    registryCreds
  ]
}

resource virtualCustomerImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'virtual-customer-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/virtual-customer/Dockerfile'
    build: {
      platforms: [
        'linux/amd64'
      ]
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/virtual-customer?ref=3c80efebd2889300a57f261803e79dad1e1ff611'
    }
    tag: '3c80efe'
  }
  dependsOn: [
    registryCreds
  ]
}

resource virtualWorkerImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'virtual-worker-image'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/virtual-worker/Dockerfile'
    build: {
      platforms: [
        'linux/amd64'
      ]
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/virtual-worker?ref=3c80efebd2889300a57f261803e79dad1e1ff611'
    }
    tag: '3c80efe'
  }
  dependsOn: [
    registryCreds
  ]
}

resource makelineService 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'makeline-service'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/makeline-service/main.go#L21'
    containers: {
      makeline: {
        image: makelineServiceImage.properties.imageReference
        env: {
          ORDER_DB_COLLECTION_NAME: {
            value: 'orders'
          }
          ORDER_DB_NAME: {
            value: 'orderdb'
          }
          ORDER_DB_URI: {
            valueFrom: {
              secretKeyRef: {
                key: 'connectionString'
                secretName: mongoDb.properties.secrets.name
              }
            }
          }
          ORDER_QUEUE_NAME: {
            value: 'orders'
          }
          ORDER_QUEUE_PASSWORD: {
            valueFrom: {
              secretKeyRef: {
                key: 'password'
                secretName: rabbitmqSecret.name
              }
            }
          }
          ORDER_QUEUE_URI: {
            value: 'amqp://${rabbitMq.properties.host}:${rabbitMq.properties.port}'
          }
          ORDER_QUEUE_USERNAME: {
            value: rabbitMq.properties.username
          }
        }
        ports: {
          web: {
            containerPort: 3001
          }
        }
      }
    }
  }
}

resource orderService 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'order-service'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/order-service/app.js#L6'
    containers: {
      order: {
        image: orderServiceImage.properties.imageReference
        env: {
          ORDER_QUEUE_HOSTNAME: {
            value: rabbitMq.properties.host
          }
          ORDER_QUEUE_NAME: {
            value: 'orders'
          }
          ORDER_QUEUE_PASSWORD: {
            valueFrom: {
              secretKeyRef: {
                key: 'password'
                secretName: rabbitmqSecret.name
              }
            }
          }
          ORDER_QUEUE_PORT: {
            value: string(rabbitMq.properties.port)
          }
          ORDER_QUEUE_USERNAME: {
            value: rabbitMq.properties.username
          }
        }
        ports: {
          web: {
            containerPort: 3000
          }
        }
      }
    }
  }
}

resource productService 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'product-service'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/product-service/src/main.rs#L5'
    containers: {
      product: {
        image: productServiceImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3002
          }
        }
      }
    }
  }
}

resource storeAdmin 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'store-admin'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/store-admin/src/main.ts#L8'
    containers: {
      admin: {
        image: storeAdminImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8081
          }
        }
        volumeMounts: [
          {
            mountPath: '/etc/nginx/conf.d'
            volumeName: 'nginx-config'
          }
        ]
      }
    }
    volumes: {
      'nginx-config': {
        secretName: storeAdminNginxConfig.name
      }
    }
  }
}

resource storeFront 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'store-front'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/store-front/src/main.ts#L8'
    containers: {
      front: {
        image: storeFrontImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8080
          }
        }
        volumeMounts: [
          {
            mountPath: '/etc/nginx/conf.d'
            volumeName: 'nginx-config'
          }
        ]
      }
    }
    volumes: {
      'nginx-config': {
        secretName: storeFrontNginxConfig.name
      }
    }
  }
}

resource virtualCustomer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'virtual-customer'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/virtual-customer/src/main.rs#L7'
    containers: {
      customer: {
        image: virtualCustomerImage.properties.imageReference
        env: {
          ORDERS_PER_HOUR: {
            value: '30'
          }
          ORDER_SERVICE_URL: {
            value: 'http://${orderService.properties.hosts.order}:3000/'
          }
        }
      }
    }
  }
}

resource virtualWorker 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'virtual-worker'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'src/virtual-worker/src/main.rs#L6'
    containers: {
      worker: {
        image: virtualWorkerImage.properties.imageReference
        env: {
          MAKELINE_SERVICE_URL: {
            value: 'http://${makelineService.properties.hosts.makeline}:3001'
          }
          ORDERS_PER_HOUR: {
            value: '20'
          }
        }
      }
    }
  }
}

resource storeAdminRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'store-admin-route'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'aks-store-all-in-one.yaml#L508'
    kind: 'HTTP'
    rules: [
      {
        matches: [
          {
            httpPath: '/'
          }
        ]
        destinationContainer: {
          resourceId: storeAdmin.id
          containerName: 'admin'
          containerPort: 8081
        }
      }
    ]
  }
}

resource storeFrontRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'store-front-route'
  properties: {
    environment: environment
    application: storeApp.id
    codeReference: 'aks-store-all-in-one.yaml#L445'
    kind: 'HTTP'
    rules: [
      {
        matches: [
          {
            httpPath: '/'
          }
        ]
        destinationContainer: {
          resourceId: storeFront.id
          containerName: 'front'
          containerPort: 8080
        }
      }
    ]
  }
}
