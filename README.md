# Installazione Kong / Konga / Keycloak

## Credits:

[Securing APIs with Kong and Keycloak - Part 1](https://www.jerney.io/secure-apis-kong-keycloak-1/) a cura di Joshua A Erney  

## Requisiti:

* [**docker**](https://docs.docker.com/install/)
* [**docker-compose**](https://docs.docker.com/compose/overview/)
* [**jq**](https://stedolan.github.io/jq/)
* [**curl** cheatsheet ;)](https://devhints.io/curl)
* Pazienza
* :coffee:

## Versioni installate:
* Kong 1.1.1 - alpine
* Konga 0.14.3
* Keycloak 6.0.0
___


## 0. Introduzione
Questo è un riassunto dell'articolo indicato tra i credits del quale è indispensabile la lettura per la comprensione  di quanto di seguito.
Vi consiglio altresì di leggere i vari links di rimando, in quanto sono utili per gli approfondimenti del caso.

Il file *docker-compose.yml* contiene già l'intera "infrastruttura" descritta nell'articolo. Scopo di questo README è di adeguare il contenuto dell'articolo alle versioni attuali ed eventualmente aggiungere qualche dettaglio informativo laddove necessario.

**N.B.** - All'interno del *docker-compose.yml* sono presenti credenziali di *default* e l'installazione che si ottiene non è un sistema *production-ready*.


## 1. Creare l'immagine di Kong + Oidc

[kong-oidc](https://github.com/nokia/kong-oidc) è un plugin per kong che consente di implementare OpenID Connect RP (Relying Party).

### 1.1 Breve introduzione a OIDC

OpenID è un semplice livello di identità implementato al di sopra del protocollo OAuth 2.0: consente ai suoi Clients di verificare l'identità dell'utente finale, basata sulla autenticazione eseguita da un Server di Autorizzazione, oltre che di ottenere informazioni base sul profilo utente.

Con un Security Token Service (STS), l'RP viene reindirizzato a un STS, che autentica l'RP e rilascia un token di sicurezza che concede l'accesso, invece dell'applicazione che autentica direttamente l'RP. Le attestazioni vengono estratte dai token e utilizzate per le attività relative all'identità.

Lo standard OpenID definisce una situazione in cui un sito cooperante può agire come un RP, consentendo all'utente di accedere a più siti utilizzando un set di credenziali. L'utente beneficia del fatto di non dover condividere le credenziali di accesso con più siti e gli operatori del sito che collabora non devono sviluppare il proprio meccanismo di accesso.

Links utili

* [Relying Party](https://en.wikipedia.org/wiki/Relying_party)
* [Claims based identity](https://en.wikipedia.org/wiki/Claims-based_identity)
* [OpenID](https://en.wikipedia.org/wiki/OpenID)

### 1.2 Costruzione della immagine

Rispetto alla impostazione proposta dall'autore dell'articolo da cui siamo partiti, procederemo a implementare una immagine basata sua alpine linux.

```
FROM kong:1.1.1-alpine

LABEL description="Alpine + Kong 1.1.1 + kong-oidc plugin"

RUN apk update && apk add git unzip luarocks
RUN luarocks install kong-oidc
```

Questo il contenuto del Dockerfile allegato a questa breve guida.

Ci basterà dare il comando:

```bash
# docker build -t kong:1.1.1-alpine-oidc .
```

e attendere la build dell'immagine. 

## 2. Kong DB + Migrazioni

Tiriamo su il servizio kong-db:

```bash
docker-compose up -d kong-db
```

Lanciamo le migrazioni di kong:

```bash
docker-compose run --rm kong kong migrations bootstrap
```

A questo punto possiamo avviare kong:

```bash
docker-compose up -d kong
```

Verifichiamo di avere in esecuzione i due servizi:
```
# docker-compose ps
```

Verifichiamo che il plugin OIDC sia presente su Kong:

```bash
 curl -s http://localhost:8001 | jq .plugins.available_on_server.oidc
```

Il risultato di questa chiamata dovrebbe essere `true`. La presenza del plugin non indica che esso sia già attivo.

## 3. Konga

Konga è un pannello di amministrazione per Kong. Ci offre un pannello visuale attraverso cui espletare le configurazioni di Kong (oltre che ispezionare le configurazioni fatte da riga di comando).

Avviamo konga con il comando:

```bash
docker-compose up -d konga
```

Konga è in ascolto alla porta 1337. Perciò avviamo un browser e puntiamo alla url  [http://localhost:1337](http://localhost:1337).

La prima volta che accediamo a konga dovremo registrare l'account amministratore. Per i tests, usate credenziali semplici, facili da ricordare. Per i sistemi di produzione, usate password che rispettino gli standard di sicurezza!

Dopo aver registrato l'utente amminsitratore, sarà possibile effettuare l'accesso.

Completato l'accesso, dovremo attivare la connessione a Kong. Inserire in "Name" il valore "kong" e come "Kong Admin URL" il seguente indirizzo: ```http://kong:8001``` e salvare.

A questo punto avremo la nostra istanza di Konga pronta all'uso.

## 4. Creazione di un servizio e di una rotta

Per testare il sistema, useremo [Mockbin](http://mockbin.org/) (un servizio che consente di generare degli endpoint per testare richieste HTTP, risposte, sockets e API).

Come riferimento, si rimanda alle [Admin API di Kong](https://docs.konghq.com/1.1.x/admin-api).

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

Prendere nota del proprio service id (nell'esempio è e71c82d3-2e53-469b-9beb-a232a15f86d4) ed utilizzarlo per effettuare la successiva chiamata all'api di kong che consente di aggiungere una rotta al servizio

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

Verifichiamo che tutto funzioni:

```bash
$ curl -s http://localhost:8000/mock
{
  "startedDateTime": "2019-04-24T22:49:26.886Z",
  "clientIPAddress": "172.20.0.1",
  "method": "GET",
  "url": "http://localhost/request",
  "httpVersion": "HTTP/1.1",

```

# 5. Keycloak

Avviamo il servizio database id keycloak:

```bash
docker-compose up -d keycloak-db
```

Avviamo il servizio di keycloak:

```bash
docker-compose up -d keycloak
```

Verifichiamo che sia tutto in piedi con un:

```bash
docker-compose ps
```

A questo punto rimando alla sezione dell'articolo che illustra come configurare keycloak ai fini del test.

Keycloak sarà disponibile alla url [http://localhost:8180](http://localhost:8180).

Le credenziali sono recuperabili dal file docker-compose.yml (quelle di default sono admin/admin)


## 6. Attivazione di keycloak sulla route di test

Nell'articolo viene indicato che, per poter attivare la funionalità dell'OIDC con Kong come client di Keycloak, bisogna invocare una Admin Rest API di Kong.

L'API in questione è [/plugins](https://docs.konghq.com/1.1.x/admin-api/#add-plugin) che consente di aggiungere un plugin globalmente a Kong.

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
