# Installazione Kong / Konga / Keycloak

## Credits:

[Securing APIs with Kong and Keycloak - Part 1](https://www.jerney.io/secure-apis-kong-keycloak-1/) by Joshua A Erney  

## Requirements:

* [**docker**](https://docs.docker.com/install/)
* [**docker-compose**](https://docs.docker.com/compose/overview/)
* [**jq**](https://stedolan.github.io/jq/)
* [**curl** cheatsheet ;)](https://devhints.io/curl)
* Patience
* :coffee:

## Installed versions:
* Kong 1.3.0 - alpine
* Konga 0.14.3
* Keycloak 7.0.0
___


## 0. Introduction
I reviewed the content of this page, and I decided to turn it into a complete guide and translate it from Italian to 
English to make it universal to read: the previous version was a summary of the article indicated among the credits 
(whose reading is useful for understanding what follows).

I also advise you to read the various reference links, as they are useful for further investigation.

The *docker-compose.yml* file already contains the entire "infrastructure" described in the article. The purpose of 
this README is to adapt the content of the article to the current versions of the applications and possibly add some 
informative details where necessary.

:danger: *Warning*- Inside the *docker-compose.yml* there are default credentials and the installation you get is not a 
*production-ready* system. 


## 1. Create the image of Kong + Oidc

[kong-oidc](https://github.com/nokia/kong-oidc) is a kong plugin that allows you to implement OpenID Connect RP (Relying 
Party).

### 1.1 Brief introduction to OIDC

OpenID is a simple level of identity implemented above the OAuth 2.0 protocol: it allows its Clients to verify the 
identity of the end user, based on the authentication performed by an Authorization Server, as well as to obtain basic 
information on the user profile.

With a Security Token Service (STS), the RP is redirected to an STS, which authenticates the RP and issues a security 
token that grants access, instead of the application that directly authenticates the RP. Claims are extracted from 
tokens and used for identity-related activities.

The OpenID standard defines a situation in which a cooperating site can act as an RP, allowing the user to access 
multiple sites using a set of credentials. The user benefits from not having to share access credentials with multiple 
sites and the operators of the collaborating site must not develop their own access mechanism.

:point_right: Useful Links

* [Relying Party](https://en.wikipedia.org/wiki/Relying_party)
* [Claims based identity](https://en.wikipedia.org/wiki/Claims-based_identity)
* [OpenID](https://en.wikipedia.org/wiki/OpenID)

### 1.2 Construction of the docker image

Compared to the setting proposed by the author of the article from which we started, we will proceed to implement an 
image based on his alpine linux.

This is the content of the Dockerfile attached to this brief guide:

```
FROM kong:1.3.0-alpine

LABEL description="Alpine + Kong 1.3.0 + kong-oidc plugin"

RUN apk update && apk add git unzip luarocks
RUN luarocks install kong-oidc
```

We will just have to give the command:

```bash
# docker build -t kong:1.3.0-alpine-oidc .
```

and wait for the image to build.

## 2. Kong DB + Database Migrations

Kong uses a database server (postgresql in our case). For this reason it is necessary to initialize the database by 
launching the necessary migrations.

First we start the kong-db service:

```bash
docker-compose up -d kong-db
```

Let's launch kong migrations:

```bash
docker-compose run --rm kong kong migrations bootstrap
```

At this point we can start kong:

```bash
docker-compose up -d kong
```

Let's verify that you have the two services running:
```
# docker-compose ps
```

And finally, let's verify that the OIDC plugin is present on Kong:

```bash
 curl -s http://localhost:8001 | jq .plugins.available_on_server.oidc
```

The result of this call should be `true`. The presence of the plugin does not indicate that it is 
already active.

## 3. Konga

Konga is an administration panel for Kong. It offers us a visual panel through which to carry out Kong's 
configurations (as well as inspect the configurations made from the command line).

We start konga with the command:

```bash
docker-compose up -d konga
```

onga is listening on port 1337. Therefore we launch a browser and point to the url 
[http://localhost:1337](http://localhost:1337).

The first time we log in to konga we will need to register the administrator account. For tests, use 
simple, easy-to-remember credentials. For production systems, use passwords that meet safety standards!

After registering the administrator user, it will be possible to log in.

Once logged in, we will need to activate the connection to Kong. Enter in "Name" the value "kong" and 
as "Kong Admin URL" the following address: ```http://kong:8001``` then save.

At this point we will have our instance of Konga ready for use!

## 4. Creation of a service and a route

To test the system, we will use [Mockbin](http://mockbin.org/) (a service that generates endpoints to 
test HTTP requests, responses, sockets and APIs).

As a reference, please refer to [Kong's Admin API](https://docs.konghq.com/1.3.x/admin-api).

```bash
$ curl -s -X POST http://localhost:8001/services \
    -d name=mock-service \
    -d url=http://mockbin.org/request \
    | python -mjson.tool
{
    "connect_timeout": 60000,
    "created_at": 1556145691,
    "host": "mockbin.org",
    "id": "46ddff80-4368-49fa-9f4b-b0f67f9296ad",
    ...
}
```

Make a note of your service id (in the example it is e71c82d3-2e53-469b-9beb-a232a15f86d4) and use it 
to make the next call to kong's api that allows you to add a route to the service.

```bash
$ curl -s -X POST http://localhost:8001/services/e71c82d3-2e53-469b-9beb-a232a15f86d4/routes -d "paths[]=/mock" \
    | python -mjson.tool
{
    "created_at": 1556146020,
    "destinations": null,
    "hosts": null,
    "id": "7990c9ee-7b30-4ff5-b230-e20f85a565d3",
    "methods": null,
    "name": null,
    "paths": [
        "/mock"
    ],

    ...
}
```

We verify that everything works:

```bash
$ curl -s http://localhost:8000/mock
{
  "startedDateTime": "2019-04-24T22:49:26.886Z",
  "clientIPAddress": "172.20.0.1",
  "method": "GET",
  "url": "http://localhost/request",
  "httpVersion": "HTTP/1.1",

```

# 5. Keycloak containers

We start the keycloak database service:

```bash
docker-compose up -d keycloak-db
```

We start the keycloak service:

```bash
docker-compose up -d keycloak
```

We check that everything is standing with:

```bash
docker-compose ps
```

We should see all the containers running:

```bash
                     Name                                   Command               State                                               Ports                                             
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
kong-konga-keycloak_keycloak-db_1_6cf898ee0278   docker-entrypoint.sh postgres    Up      0.0.0.0:25432->5432/tcp                                                                       
kong-konga-keycloak_keycloak_1_86084fa93065      /opt/jboss/tools/docker-en ...   Up      0.0.0.0:8180->8080/tcp, 8443/tcp                                                              
kong-konga-keycloak_kong-db_1_74c7d714a18f       docker-entrypoint.sh postgres    Up      0.0.0.0:15432->5432/tcp                                                                       
kong-konga-keycloak_kong_1_db9239a81fc8          /docker-entrypoint.sh kong ...   Up      0.0.0.0:8000->8000/tcp, 0.0.0.0:8001->8001/tcp, 0.0.0.0:8443->8443/tcp, 0.0.0.0:8444->8444/tcp
kong-konga-keycloak_konga_1_e925524dbfcb         /app/start.sh                    Up      0.0.0.0:1337->1337/tcp                                                                        


```

## 6. Configuration of realm and clients in Keycloak

Keycloak will be available at the url [http://localhost:8180](http://localhost:8180).

You can login using credentials inside the docker-compose.yml file. (default credentials are 
admin/admin)

![Keycloak Login](images/keycloak-login.png)


After login, click on the button "Add Realm": this button appears when your mouse is over the realm 
name (Master) on the upper left corner:

![Keycloak add Realm](images/keycloak-add-realm.png)

You need to give the realm a name. For this README i've choosen the name "experimental" but you can 
choose the name you prefer:

![Keycloak New Realm](images/keycloak-new-realm.png)

Once saved, you'll be redirected to the realm settings page:

![Keycloak realm settings](images/keycloak-realm-settings-1.png)

This page has a lot of tabs, with lots of configuration fields :astonished:

However, after the realm is created, we need to add two clients:

- One client that will be used by Kong, through the OIDC plugin
- Another client that we'll use to access the API through Kong.

We'll name the first client "kong". Choose "Clients" from the left side bar menu, then click the 
"Create" button on the right side of the page.

![Keycloak create client](images/keycloak-create-client-1.png)

Fill in the "Client ID" field with then "kong" string then save.

![Keycloak client settings](images/keycloak-client-settings-1.png)

Pay attention to the fields:

- *Client Protocol*: this account is for OIDC, so choose "openid-connect"
- *Access Type*: "confidential". This clients requires a secret to initiate the login process. This
key will be used later on kong OIDC configuration.
- *Root Url*
- *Valid redirect URLs*

Under tab "Credentials", you'll find the Secret that we'll use to configure Kong OIDC:

![Keycloak client settings](images/keycloak-client-settings-2.png)

Now, create a second client, named "myapp".

![Keycloak Create Client 2](images/keycloak-create-client-2.png)

The important thing here is the access type: "public" means that the login process needs users credentials to be
completed.

So, let's create a user that we'll use, later, to perform authentication.

Click, from the left side menu, the item "Manage" > "Users", then click - from the right side - the "Add User" button.

![Create User](images/keycloak-create-user-1.png)

Pay attention to the "Email Verified" field (you should set it to on, otherwise keycloak will try to validate user's
email).
The user doesn't still have a password. So go under "Credentials" tab and fill the fields "New password" and "Password
Confirmation" with the user's password. Put the "Temporary" switch to "Off", otherwise keycloak will ask the user to
change the password at the first login.

For the purpose of this README, the password i'll use for my user is "demouser".

Click "Reset Password" to apply the new credential.

![Change Password](images/keycloak-user-change-password.png)

------ TBC------------

## 6. Attivazione di keycloak sulla route di test

per poter attivare la funionalità dell'OIDC con Kong come client di Keycloak, bisogna invocare una Admin Rest API di Kong.

L'API in questione è [/plugins](https://docs.konghq.com/1.3.x/admin-api/#add-plugin) che consente di aggiungere un plugin globalmente a Kong.

Per aggiugnere il plugin di OIDC, occorrono alcune informazioni:

- L'indirizzo IP della nostra macchina (questo perchè la redirezione andrebbe fatta su una URL del servizio di keycloak, ma nell'esempio kong gira in un container e in un segmento di rete diverso da quello di keycloak).
- la CLIENT_SECRET recuperabile dal tab "Credential" disponibile nella scheda del client "kong" aggiunto durante la fase di configurazione di Keycloak.

A questo punto, assumendo che il proprio IP sia 192.168.0.1, possiamo invocare questa chiamata:

```bash
$ HOST_IP="192.168.0.1"
$ CLIENT_SECRET="0eb63fbb-5b23-4f4e-96ca-6f837d94edfd"
$ curl -s -X POST http://localhost:8001/plugins \
  -d name=oidc \
  -d config.client_id=kong \
  -d config.client_secret=${CLIENT_SECRET} \
  -d config.discovery=http://${HOST_IP}:8180/auth/realms/master/.well-known/openid-configuration \
  | python -mjson.tool
{
    "config": {
        "bearer_only": "no",
        "client_id": "kong",
        "client_secret": "0eb63fbb-5b23-4f4e-96ca-6f837d94edfd",
        "discovery": "http://192.168.88.19:8180/auth/realms/master/.well-known/openid-configuration",
        "filters": null,
        "introspection_endpoint": null,
        "introspection_endpoint_auth_method": null,
        "logout_path": "/logout",
        "realm": "kong",

    ...
}
```

La configurazione appena completata è amministrabile attraverso Konga :)

Ad ogni modo, se proveremo ad accedere alla URL [http://localhost:8000/mock](http://localhost:8000/mock), Kong dovrebbe redirezionarci in Keycloak, dove potremo autenticarci con le credenziali create in precedenza.

