const { Client } = require('pg');
const express = require('express');
const fs = require('fs');

// DB_SSL=true habilita TLS (obrigatório no RDS PostgreSQL 15+). Valida o certificado com o bundle de CA da RDS.
const RDS_CA_PATH = process.env.DB_SSL_CA || '/app/certs/rds-global-bundle.pem'
const dbSsl = process.env.DB_SSL === 'true'
    ? { ca: fs.readFileSync(RDS_CA_PATH).toString(), rejectUnauthorized: true }
    : undefined;


(async () => {
    const app = express()
    const port = process.env.API_PORT || 3000
    let i = 0

    app.listen(port, () => {
        console.log(`API iniciada. Escutando PORT ${port}`)
    })

    app.use((req, res, next) => {
        i++;
        next();
    })

    app.get('/', async (req, res) => {
        const response = { 'message': "API OK!", 'request_id': i }
        console.log(response)
        res.send(response)
    })

    app.get('/connect', async (req, res) => {
        try {
            const client = new Client({
                user: process.env.DB_USER,
                host: process.env.DB_HOST,
                database: process.env.DB_DATABASE,
                password: process.env.DB_PASSWORD,
                port: process.env.DB_PORT || 5432,
                ssl: dbSsl,
            })
            await client.connect()

            const result = await client.query('SELECT version()')
            const version = result.rows[0].version

            await client.end()

            const response = { 'message': "Conectado ao banco", 'version': version, 'request_id': i }
            console.log(response)
            res.send(response)
        } catch (e) {
            const error = { 'message': 'Erro ao se conectar ao banco', 'request_id': i }
            console.log(error)
            console.log(e)

            res.status(500);
            res.send(error)
        }
    })
})()
