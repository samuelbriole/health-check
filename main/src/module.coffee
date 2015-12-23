express = require 'express'
Promise = require 'bluebird'
prettyHrtime = require 'pretty-hrtime'
_ = require 'lodash'

module.exports = (params = {}) ->
  defaultParams =
    urn: '/api/health-check'
  config = _.defaults params, defaultParams

  app = express()
  start = process.hrtime()

  uptime = ->
    prettyHrtime process.hrtime start

  pingMongoAsync = (mongoConnectionDb) ->
    new Promise((fulfill,reject)->
      callback = (err,result) ->
        if err
          return reject err
        else
          return fulfill result

      mongoConnectionDb.collection('dummy').findOne { _id: 1 }, callback
      ).timeout(1000)

  pingPostgresAsync = (postgresClient) ->
    new Promise((fulfill,reject)->
      callback = (err,result) ->
        if err
          return reject err
        else
          return fulfill result

      postgresClient.query 'SELECT NOW() AS "theTime"', callback
      ).timeout(1000)

  pingElasticsearchAsync = (elasticsearchClt) ->
    new Promise((fulfill,reject) ->
      callback = (err,result) ->
        if err
          return reject err
        else
          return fulfill result

      elasticsearchClt.ping {
        requestTimeout: 3000
        hello: 'elasticsearch!'
        }, callback
    )

  app.get config.urn, (req, res, next) ->
    body = {}
    body['uptime'] = uptime()

    #Check postgres connection
    postgresPromise = null
    console.log config.postgres
    if _.isFunction config.postgres?.getPostgresClient
      postgresClient = config.postgres.getPostgresClient()
      postgresPromise = pingPostgresAsync(postgresClient)
      .then ->
        body['postgres'] =
          status: 'ok'
      .catch (err) ->
        body['postgres'] =
          status: 'ko'

    # checkMongo = (driver, dbConfig) ->
    #
    #   new Promise (fulfill,reject)->
    #     # Db = driver.Db
    #     # Server = driver.Server
    #     #
    #     # db = new Db dbConfig.name, new Server(dbConfig.host, dbConfig.port)
    #     # Establish connection to db
    #     console.log config.mongo.connection
    #     config.mongo.connection.stats (err, db) ->
    #       console.log err
    #       console.log info
    #       # return reject err if err?
    #       # # Retrive the server Info
    #       # db.stats (err, info) ->
    #       #   console.log err
    #       #   console.log info
    #       #   # db.close()
    #       return reject err if err?
    #       return fulfill db
    #
    # # Check mongo
    # if config.mongo?.driver? and config.mongo?.config?
    #   mongoPromise = checkMongo(config.mongo.driver, config.mongo.config)
    #   .then (info) ->
    #     body['mongo'] =
    #       status: if info.ok is 1 then 'ok' else 'ko'
    #   .catch (err) ->
    #     body['mongo'] =
    #       status: 'ko'


    # promises.push 'elasticsearch'
    #
    # #Check elasticsearch connections
    # if config.elasticsearchClts
    #   elasticsearchClts = config.elasticsearchClts()
    #   for elasticsearchClt in elasticsearchClts
    #     promises.push pingElasticsearchAsync(elasticsearchClt)
    #
    Promise.all([postgresPromise]).then ->
      res.send body
  return app
