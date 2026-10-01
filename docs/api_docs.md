# MoMo REST API — Documentation

Base URL: `http://127.0.0.1:8000`

All endpoints require **Basic Authentication** and return JSON.

- Server: `api/app.py` (plain Python `http.server`)
- Credentials: `admin` / `Maureen123!` (overridable via `API_USER` / `API_PASS`)
- Data: `data/modified_sms_v2.json` (parsed from `modified_sms_v2.xml` by `dsa/parse_xml.py`)

---

## Authentication

Credentials are sent with every request in the `Authorization` header:

```
Authorization: Basic <base64("admin:Maureen123!")>
```

`curl` does this automatically with the `-u` flag:

```bash
curl -u admin:'Maureen123!' http://127.0.0.1:8000/transactions
```

| Request | Result |
|---|---|
| Missing or invalid credentials | `401 Unauthorized` + `WWW-Authenticate: Basic realm="momo_api"` |
| Valid credentials | `200 OK` (or the appropriate success code) |

**Why Basic Auth is weak:** the `username:password` pair is only Base64-encoded — not encrypted — so it can be decoded by anyone who intercepts the request unless used over HTTPS. There is no expiry, no scope limiting, and no way to revoke a single credential without changing the password for everyone.

**Stronger alternatives:**
- **JWT (JSON Web Tokens)** — a signed token issued after login, with an expiry; the server stays stateless and tokens can be scoped/revoked.
- **OAuth2 / Bearer tokens** — delegated access with scopes, refresh tokens, and standardised flows for apps and third-party clients.

---

## Endpoints

### `GET /transactions`  list all transactions

| | |
|---|---|
| **Method** | `GET` |
| **Auth** | Required |
| **Success** | `200 OK`  JSON array of all transactions |

Request:

```bash
curl -u admin:'Maureen123!' http://127.0.0.1:8000/transactions
```

Response (`200 OK`):

```json
[
  {
    "id": 1,
    "address": "M-Money",
    "date": "1715351458724",
    "readable_date": "10 May 2024 4:30:58 PM",
    "type": "1",
    "status": "-1",
    "body": "You have received 2000 RWF from Jane Smith (*********013) ...",
    "contact_name": "(Unknown)",
    "service_center": "+250788110381",
    "amount": 2000.0
  }
]
```

### `GET /transactions/{id}`  view one transaction

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/transactions/1` |
| **Success** | `200 OK` — one JSON object |
| **Error** | `404 Not Found` if the id does not exist |

Request:

```bash
curl -u admin:'Maureen123!' http://127.0.0.1:8000/transactions/1
```

Response (`200 OK`):

```json
{
  "id": 1,
  "address": "M-Money",
  "date": "1715351458724",
  "readable_date": "10 May 2024 4:30:58 PM",
  "type": "1",
  "status": "-1",
  "body": "You have received 2000 RWF from Jane Smith ...",
  "contact_name": "(Unknown)",
  "service_center": "+250788110381",
  "amount": 2000.0
}
```

Error (`404 Not Found`):

```json
{ "error": "transaction 99999 not found" }
```

### `POST /transactions`  add a new transaction

| | |
|---|---|
| **Method** | `POST` |
| **Body** | JSON object (any fields; a numeric `id` is assigned automatically) |
| **Success** | `201 Created` — the new record including its `id` |
| **Error** | `400 Bad Request` if the body is not a valid JSON object |

Request:

```bash
curl -u admin:'Maureen123!' -X POST http://127.0.0.1:8000/transactions \
  -H 'Content-Type: application/json' \
  -d '{"address":"M-Money","body":"You have received 500 RWF from Test Sender","amount":500.0}'
```

Response (`201 Created`):

```json
{
  "id": 1692,
  "address": "M-Money",
  "body": "You have received 500 RWF from Test Sender",
  "amount": 500.0
}
```

Error (`400 Bad Request`):

```json
{ "error": "body must be a valid JSON object" }
```

### `PUT /transactions/{id}`  update an existing transaction

| | |
|---|---|
| **Method** | `PUT` |
| **Path** | `/transactions/1692` |
| **Body** | JSON object — fields to update |
| **Success** | `200 OK` — the updated record |
| **Error** | `404 Not Found` if the id does not exist; `400 Bad Request` for invalid JSON |

Request:

```bash
curl -u admin:'Maureen123!' -X PUT http://127.0.0.1:8000/transactions/1692 \
  -H 'Content-Type: application/json' \
  -d '{"amount":750.0}'
```

Response (`200 OK`):

```json
{
  "id": 1692,
  "address": "M-Money",
  "body": "You have received 500 RWF from Test Sender",
  "amount": 750.0
}
```

### `DELETE /transactions/{id}`  delete a transaction

| | |
|---|---|
| **Method** | `DELETE` |
| **Path** | `/transactions/1692` |
| **Success** | `200 OK` — the removed record |
| **Error** | `404 Not Found` if the id does not exist |

Request:

```bash
curl -u admin:'Maureen123!' -X DELETE http://127.0.0.1:8000/transactions/1692
```

Response (`200 OK`): the deleted record is returned as JSON.

---

## Error codes

| Code | Meaning | When |
|---|---|---|
| `200` | OK | Successful `GET`, `PUT`, `DELETE` |
| `201` | Created | Successful `POST` |
| `400` | Bad Request | Request body is not a valid JSON object |
| `401` | Unauthorized | Missing or invalid credentials |
| `404` | Not Found | Unknown route, or id does not exist |

---

## How to Setup & run

```bash
# 1. Create the parsed data (only needed once)
python -m dsa.parse_xml            # -> data/modified_sms_v2.json

# 2. Start the API
python api/app.py                  # http://127.0.0.1:8000

# optional environment overrides
API_USER=admin API_PASS='Maureen123!' API_PORT=8000 python api/app.py
```
