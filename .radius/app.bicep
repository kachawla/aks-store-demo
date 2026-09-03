extension radius

param environment string

@secure()
param rabbitmqPassword string

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
  name: 'mongo'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/makeline-service/mongodb.go#L105'
    database: 'orderdb'
  }
}

resource rabbitmq 'Radius.Messaging/rabbitMQ@2025-08-01-preview' = {
  name: 'rabbitmq'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/order-service/plugins/messagequeue.js#L4'
    queue: 'orders'
    username: 'username'
    password: rabbitmqSecret.id
  }
}

resource rabbitmqSecret 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'rabbitmq-secret'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/order-service/plugins/messagequeue.js#L30'
    data: {
      password: {
        value: rabbitmqPassword
      }
    }
  }
}

resource registryCreds 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'radius-ghcr-registry-creds'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: '.radius/app.bicep#L59'
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
  name: 'store-admin-config'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/store-admin/nginx.conf'
    data: {
      'default.conf': {
        value: 'server {\n    listen       8081;\n    listen  [::]:8081;\n    server_name  localhost;\n\n    client_max_body_size 10m;\n\n    location / {\n        root   /usr/share/nginx/html;\n        index  index.html index.htm;\n        try_files $uri $uri/ /index.html;\n    }\n\n    error_page   500 502 503 504  /50x.html;\n\n    location = /50x.html {\n        root   /usr/share/nginx/html;\n    }\n\n    location /health {\n        default_type application/json;\n        return 200 \'{"status":"ok","version":"0.1.0"}\';\n    }\n\n    location ~ ^/api/makeline/order/(?<id>\\w+) {\n        proxy_pass http://${makelineServiceContainer.properties.hosts.makeline}:3001/order/$id;\n        proxy_http_version 1.1;\n    }\n\n    location /api/makeline/order {\n        proxy_pass http://${makelineServiceContainer.properties.hosts.makeline}:3001/order;\n        proxy_http_version 1.1;\n    }\n\n    location /api/makeline/order/fetch {\n        proxy_pass http://${makelineServiceContainer.properties.hosts.makeline}:3001/order/fetch;\n        proxy_http_version 1.1;\n    }\n\n    location /api/order {\n        rewrite ^/api/order$ / break;\n        rewrite ^/api/order(/.*)$ $1 break;\n        proxy_pass http://${orderServiceContainer.properties.hosts.order}:3000;\n        proxy_http_version 1.1;\n    }\n\n    location /api/products/ {\n        proxy_pass http://${productServiceContainer.properties.hosts.product}:3002/;\n        proxy_http_version 1.1;\n    }\n\n    location /api/products {\n        rewrite ^/api/products$ / break;\n        rewrite ^/api/products(/.*)$ $1 break;\n        proxy_pass http://${productServiceContainer.properties.hosts.product}:3002;\n        proxy_http_version 1.1;\n    }\n\n    location ~ ^/api/product/(?<id>\\w+) {\n        proxy_pass http://${productServiceContainer.properties.hosts.product}:3002/$id;\n        proxy_http_version 1.1;\n    }\n\n    location /api/product {\n        rewrite ^/api/product$ / break;\n        rewrite ^/api/product(/.*)$ $1 break;\n        proxy_pass http://${productServiceContainer.properties.hosts.product}:3002;\n        proxy_http_version 1.1;\n    }\n\n    location /api/product/ {\n        proxy_pass http://${productServiceContainer.properties.hosts.product}:3002/;\n        proxy_http_version 1.1;\n    }\n\n    location /api/ai/health {\n        proxy_pass http://${productServiceContainer.properties.hosts.product}:3002/ai/health;\n        proxy_http_version 1.1;\n    }\n\n    location /api/ai/generate/description {\n        proxy_pass http://${productServiceContainer.properties.hosts.product}:3002/ai/generate/description;\n        proxy_http_version 1.1;\n    }\n\n    location /api/ai/generate/image {\n        proxy_pass http://${productServiceContainer.properties.hosts.product}:3002/ai/generate/image;\n        proxy_http_version 1.1;\n        proxy_connect_timeout 30s;\n        proxy_read_timeout 300s;\n        proxy_send_timeout 300s;\n    }\n}\n'
      }
    }
  }
}

resource storeFrontConfig 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'store-front-config'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'src/store-front/nginx.conf'
    data: {
      'default.conf': {
        value: 'server {\n    listen       8080;\n    listen  [::]:8080;\n    server_name  localhost;\n\n    location / {\n        root   /usr/share/nginx/html;\n        index  index.html index.htm;\n        try_files $uri $uri/ /index.html;\n    }\n\n    error_page   500 502 503 504  /50x.html;\n\n    location = /50x.html {\n        root   /usr/share/nginx/html;\n    }\n\n    location /health {\n        default_type application/json;\n        return 200 \'{"status":"ok","version":"0.1.0"}\';\n    }\n\n    location /api/orders {\n        rewrite ^/api/orders$ / break;\n        rewrite ^/api/orders(/.*)$ $1 break;\n        proxy_pass http://${orderServiceContainer.properties.hosts.order}:3000;\n        proxy_http_version 1.1;\n    }\n\n    location /api/products {\n        rewrite ^/api/products$ / break;\n        rewrite ^/api/products(/.*)$ $1 break;\n        proxy_pass http://${productServiceContainer.properties.hosts.product}:3002;\n        proxy_http_version 1.1;\n    }\n}\n'
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
    tag: '80d0412'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/makeline-service?ref=80d04125366f66d72fda4ebbc3c57d473ca66e85'
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
    tag: '80d0412'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/order-service?ref=80d04125366f66d72fda4ebbc3c57d473ca66e85'
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
    tag: '80d0412'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/product-service?ref=80d04125366f66d72fda4ebbc3c57d473ca66e85'
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
    tag: '80d0412'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/store-admin?ref=80d04125366f66d72fda4ebbc3c57d473ca66e85'
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
    tag: '80d0412'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/store-front?ref=80d04125366f66d72fda4ebbc3c57d473ca66e85'
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
    tag: '80d0412'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/virtual-customer?ref=80d04125366f66d72fda4ebbc3c57d473ca66e85'
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
    tag: '80d0412'
    build: {
      source: 'git::https://github.com/kachawla/aks-store-demo.git//src/virtual-worker?ref=80d04125366f66d72fda4ebbc3c57d473ca66e85'
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
                secretName: rabbitmqSecret.name
                key: 'password'
              }
            }
          }
          ORDER_QUEUE_URI: {
            value: 'amqp://${rabbitmq.properties.host}:${rabbitmq.properties.port}'
          }
          ORDER_QUEUE_USERNAME: {
            value: 'username'
          }
        }
        ports: {
          web: {
            containerPort: 3001
          }
        }
        livenessProbe: {
          httpGet: {
            path: '/liveness'
            port: 3001
          }
          failureThreshold: 5
          initialDelaySeconds: 3
          periodSeconds: 3
        }
        readinessProbe: {
          httpGet: {
            path: '/health'
            port: 3001
          }
          failureThreshold: 3
          initialDelaySeconds: 3
          periodSeconds: 5
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
      order: {
        image: orderServiceImage.properties.imageReference
        env: {
          FASTIFY_ADDRESS: {
            value: '0.0.0.0'
          }
          ORDER_QUEUE_HOSTNAME: {
            value: rabbitmq.properties.host
          }
          ORDER_QUEUE_NAME: {
            value: 'orders'
          }
          ORDER_QUEUE_PASSWORD: {
            valueFrom: {
              secretKeyRef: {
                secretName: rabbitmqSecret.name
                key: 'password'
              }
            }
          }
          ORDER_QUEUE_PORT: {
            value: '${rabbitmq.properties.port}'
          }
          ORDER_QUEUE_USERNAME: {
            value: 'username'
          }
        }
        ports: {
          web: {
            containerPort: 3000
          }
        }
        livenessProbe: {
          httpGet: {
            path: '/health'
            port: 3000
          }
          failureThreshold: 5
          initialDelaySeconds: 3
          periodSeconds: 3
        }
        readinessProbe: {
          httpGet: {
            path: '/health'
            port: 3000
          }
          failureThreshold: 3
          initialDelaySeconds: 3
          periodSeconds: 5
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
      product: {
        image: productServiceImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3002
          }
        }
        livenessProbe: {
          httpGet: {
            path: '/health'
            port: 3002
          }
          failureThreshold: 5
          initialDelaySeconds: 3
          periodSeconds: 3
        }
        readinessProbe: {
          httpGet: {
            path: '/health'
            port: 3002
          }
          failureThreshold: 3
          initialDelaySeconds: 3
          periodSeconds: 5
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
    codeReference: 'src/store-admin/src/main.ts#L13'
    containers: {
      storeAdmin: {
        image: storeAdminImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8081
          }
        }
        livenessProbe: {
          httpGet: {
            path: '/health'
            port: 8081
          }
          failureThreshold: 5
          initialDelaySeconds: 3
          periodSeconds: 3
        }
        readinessProbe: {
          httpGet: {
            path: '/health'
            port: 8081
          }
          failureThreshold: 3
          initialDelaySeconds: 3
          periodSeconds: 5
        }
        volumeMounts: [
          {
            volumeName: 'config'
            mountPath: '/etc/nginx/conf.d'
          }
        ]
      }
    }
    volumes: {
      config: {
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
    codeReference: 'src/store-front/src/main.ts#L13'
    containers: {
      storeFront: {
        image: storeFrontImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8080
          }
        }
        livenessProbe: {
          httpGet: {
            path: '/health'
            port: 8080
          }
          failureThreshold: 5
          initialDelaySeconds: 3
          periodSeconds: 3
        }
        readinessProbe: {
          httpGet: {
            path: '/health'
            port: 8080
          }
          failureThreshold: 3
          initialDelaySeconds: 3
          periodSeconds: 5
        }
        volumeMounts: [
          {
            volumeName: 'config'
            mountPath: '/etc/nginx/conf.d'
          }
        ]
      }
    }
    volumes: {
      config: {
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
            value: 'http://${orderServiceContainer.properties.hosts.order}:3000/'
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
            value: 'http://${makelineServiceContainer.properties.hosts.makeline}:3001'
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
