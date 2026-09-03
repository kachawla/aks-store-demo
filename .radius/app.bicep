extension radius

param environment string

@description('Password for the RabbitMQ broker the order pipeline uses.')
@secure()
param rabbitMqPassword string

@description('Password/token for the OCI registry the containerImages recipe pushes to (a GitHub token with write:packages for ghcr.io).')
@secure()
param registryPassword string

@description('Username for the OCI registry the containerImages recipe pushes to (the GitHub actor for ghcr.io).')
@secure()
param registryUsername string

resource aksStoreDemoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'aks-store-demo'
  properties: {
    environment: environment
  }
}

resource mongoDb 'Radius.Data/mongoDatabases@2025-08-01-preview' = {
  name: 'mongodb'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/makeline-service/mongodb.go#L127'
    database: 'orderdb'
  }
}

resource rabbitMq 'Radius.Messaging/rabbitMQ@2025-08-01-preview' = {
  name: 'rabbitmq'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/order-service/plugins/messagequeue.js#L26'
    queue: 'orders'
    username: 'myadmin'
    password: rabbitMqPassword
  }
}

resource rabbitMqSecret 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'rabbitmq-secret'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/makeline-service/consumer.go#L133'
    data: {
      PASSWORD: {
        value: rabbitMqPassword
      }
    }
  }
}

resource registryCreds 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'radius-ghcr-registry-creds'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: '.github/workflows/release-container-images.yaml#L57'
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

resource storeAdminConfig 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'store-admin-nginx-config'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/store-admin/nginx.conf'
    data: {
      'default.conf': {
        value: join([
          'server {'
          '    listen       8081;'
          '    listen  [::]:8081;'
          '    server_name  localhost;'
          ''
          '    client_max_body_size 10m;'
          ''
          '    location / {'
          '        root   /usr/share/nginx/html;'
          '        index  index.html index.htm;'
          '        try_files $uri $uri/ /index.html;'
          '    }'
          ''
          '    error_page   500 502 503 504  /50x.html;'
          '    location = /50x.html {'
          '        root   /usr/share/nginx/html;'
          '    }'
          ''
          '    location /health {'
          '        default_type application/json;'
          '        return 200 \'{"status":"ok","version":"0.1.0"}\';'
          '    }'
          ''
          '    location ~ ^/api/makeline/order/(?<id>\\w+) {'
          '        proxy_pass http://${makelineServiceContainer.properties.hosts.makelineService}:3001/order/$id;'
          '        proxy_http_version 1.1;'
          '    }'
          ''
          '    location /api/makeline/order {'
          '        proxy_pass http://${makelineServiceContainer.properties.hosts.makelineService}:3001/order;'
          '        proxy_http_version 1.1;'
          '    }'
          ''
          '    location /api/makeline/order/fetch {'
          '        proxy_pass http://${makelineServiceContainer.properties.hosts.makelineService}:3001/order/fetch;'
          '        proxy_http_version 1.1;'
          '    }'
          ''
          '    location /api/order {'
          '        rewrite ^/api/order$ / break;'
          '        rewrite ^/api/order(/.*)$ $1 break;'
          '        proxy_pass http://${orderServiceContainer.properties.hosts.orderService}:3000;'
          '        proxy_http_version 1.1;'
          '    }'
          ''
          '    location /api/products/ {'
          '        proxy_pass http://${productServiceContainer.properties.hosts.productService}:3002/;'
          '        proxy_http_version 1.1;'
          '    }'
          ''
          '    location /api/products {'
          '        rewrite ^/api/products$ / break;'
          '        rewrite ^/api/products(/.*)$ $1 break;'
          '        proxy_pass http://${productServiceContainer.properties.hosts.productService}:3002;'
          '        proxy_http_version 1.1;'
          '    }'
          ''
          '    location ~ ^/api/product/(?<id>\\w+) {'
          '        proxy_pass http://${productServiceContainer.properties.hosts.productService}:3002/$id;'
          '        proxy_http_version 1.1;'
          '    }'
          ''
          '    location /api/product {'
          '        rewrite ^/api/product$ / break;'
          '        rewrite ^/api/product(/.*)$ $1 break;'
          '        proxy_pass http://${productServiceContainer.properties.hosts.productService}:3002;'
          '        proxy_http_version 1.1;'
          '    }'
          ''
          '    location /api/product/ {'
          '        proxy_pass http://${productServiceContainer.properties.hosts.productService}:3002/;'
          '        proxy_http_version 1.1;'
          '    }'
          ''
          '    location /api/ai/health {'
          '        proxy_pass http://${productServiceContainer.properties.hosts.productService}:3002/ai/health;'
          '        proxy_http_version 1.1;'
          '    }'
          ''
          '    location /api/ai/generate/description {'
          '        proxy_pass http://${productServiceContainer.properties.hosts.productService}:3002/ai/generate/description;'
          '        proxy_http_version 1.1;'
          '    }'
          ''
          '    location /api/ai/generate/image {'
          '        proxy_pass http://${productServiceContainer.properties.hosts.productService}:3002/ai/generate/image;'
          '        proxy_http_version 1.1;'
          '        proxy_connect_timeout 30s;'
          '        proxy_read_timeout 300s;'
          '        proxy_send_timeout 300s;'
          '    }'
          '}'
        ], '\n')
      }
    }
  }
}

resource storeFrontConfig 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'store-front-nginx-config'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/store-front/nginx.conf'
    data: {
      'default.conf': {
        value: join([
          'server {'
          '    listen       8080;'
          '    listen  [::]:8080;'
          '    server_name  localhost;'
          ''
          '    location / {'
          '        root   /usr/share/nginx/html;'
          '        index  index.html index.htm;'
          '        try_files $uri $uri/ /index.html;'
          '    }'
          ''
          '    error_page   500 502 503 504  /50x.html;'
          '    location = /50x.html {'
          '        root   /usr/share/nginx/html;'
          '    }'
          ''
          '    location /health {'
          '        default_type application/json;'
          '        return 200 \'{"status":"ok","version":"0.1.0"}\';'
          '    }'
          ''
          '    location /api/orders {'
          '        rewrite ^/api/orders$ / break;'
          '        rewrite ^/api/orders(/.*)$ $1 break;'
          '        proxy_pass http://${orderServiceContainer.properties.hosts.orderService}:3000;'
          '        proxy_http_version 1.1;'
          '    }'
          ''
          '    location /api/products {'
          '        rewrite ^/api/products$ / break;'
          '        rewrite ^/api/products(/.*)$ $1 break;'
          '        proxy_pass http://${productServiceContainer.properties.hosts.productService}:3002;'
          '        proxy_http_version 1.1;'
          '    }'
          '}'
        ], '\n')
      }
    }
  }
}

resource makelineServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'makeline-service-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/makeline-service/Dockerfile'
    tag: '0e254cc'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/makeline-service?ref=0e254cc3f9837cf03e1b165db01768e012e0aace'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource orderServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'order-service-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/order-service/Dockerfile'
    tag: '0e254cc'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/order-service?ref=0e254cc3f9837cf03e1b165db01768e012e0aace'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource productServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'product-service-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/product-service/Dockerfile'
    tag: '0e254cc'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/product-service?ref=0e254cc3f9837cf03e1b165db01768e012e0aace'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource storeAdminImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'store-admin-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/store-admin/Dockerfile'
    tag: '0e254cc'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/store-admin?ref=0e254cc3f9837cf03e1b165db01768e012e0aace'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource storeFrontImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'store-front-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/store-front/Dockerfile'
    tag: '0e254cc'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/store-front?ref=0e254cc3f9837cf03e1b165db01768e012e0aace'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource virtualCustomerImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'virtual-customer-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/virtual-customer/Dockerfile'
    tag: '0e254cc'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/virtual-customer?ref=0e254cc3f9837cf03e1b165db01768e012e0aace'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource virtualWorkerImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'virtual-worker-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/virtual-worker/Dockerfile'
    tag: '0e254cc'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/virtual-worker?ref=0e254cc3f9837cf03e1b165db01768e012e0aace'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource makelineServiceContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'makeline-service'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/makeline-service/main.go#L21'
    containers: {
      makelineService: {
        image: makelineServiceImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3001
          }
        }
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
                secretName: mongoDb.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
          ORDER_QUEUE_NAME: {
            value: 'orders'
          }
          ORDER_QUEUE_PASSWORD: {
            valueFrom: {
              secretKeyRef: {
                secretName: rabbitMqSecret.name
                key: 'PASSWORD'
              }
            }
          }
          ORDER_QUEUE_URI: {
            value: 'amqp://${rabbitMq.properties.host}:${rabbitMq.properties.port}'
          }
          ORDER_QUEUE_USERNAME: {
            value: 'myadmin'
          }
        }
      }
    }
  }
}

resource orderServiceContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'order-service'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/order-service/app.js#L6'
    containers: {
      orderService: {
        image: orderServiceImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3000
          }
        }
        env: {
          FASTIFY_ADDRESS: {
            value: '0.0.0.0'
          }
          ORDER_QUEUE_HOSTNAME: {
            value: rabbitMq.properties.host
          }
          ORDER_QUEUE_NAME: {
            value: 'orders'
          }
          ORDER_QUEUE_PASSWORD: {
            valueFrom: {
              secretKeyRef: {
                secretName: rabbitMqSecret.name
                key: 'PASSWORD'
              }
            }
          }
          ORDER_QUEUE_PORT: {
            value: '${rabbitMq.properties.port}'
          }
          ORDER_QUEUE_USERNAME: {
            value: 'myadmin'
          }
        }
      }
    }
  }
}

resource productServiceContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'product-service'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/product-service/src/main.rs#L5'
    containers: {
      productService: {
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

resource storeAdminContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'store-admin'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/store-admin/src/main.ts'
    containers: {
      storeAdmin: {
        image: storeAdminImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8081
          }
        }
        volumeMounts: [
          {
            volumeName: 'nginxConfig'
            mountPath: '/etc/nginx/conf.d'
          }
        ]
      }
    }
    volumes: {
      nginxConfig: {
        secretName: storeAdminConfig.name
      }
    }
  }
}

resource storeFrontContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'store-front'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/store-front/src/main.ts'
    containers: {
      storeFront: {
        image: storeFrontImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8080
          }
        }
        volumeMounts: [
          {
            volumeName: 'nginxConfig'
            mountPath: '/etc/nginx/conf.d'
          }
        ]
      }
    }
    volumes: {
      nginxConfig: {
        secretName: storeFrontConfig.name
      }
    }
  }
}

resource virtualCustomerContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'virtual-customer'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/virtual-customer/src/main.rs#L7'
    containers: {
      virtualCustomer: {
        image: virtualCustomerImage.properties.imageReference
        env: {
          ORDERS_PER_HOUR: {
            value: '100'
          }
          ORDER_SERVICE_URL: {
            value: 'http://${orderServiceContainer.properties.hosts.orderService}:3000/'
          }
        }
      }
    }
  }
}

resource virtualWorkerContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'virtual-worker'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/virtual-worker/src/main.rs#L6'
    containers: {
      virtualWorker: {
        image: virtualWorkerImage.properties.imageReference
        env: {
          MAKELINE_SERVICE_URL: {
            value: 'http://${makelineServiceContainer.properties.hosts.makelineService}:3001'
          }
          ORDERS_PER_HOUR: {
            value: '100'
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
    application: aksStoreDemoApp.id
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
          resourceId: storeAdminContainer.id
          containerName: 'storeAdmin'
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
    application: aksStoreDemoApp.id
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
          resourceId: storeFrontContainer.id
          containerName: 'storeFront'
          containerPort: 8080
        }
      }
    ]
  }
}
