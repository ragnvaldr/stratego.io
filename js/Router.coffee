define (require) ->

  BoardView   = require './views/BoardView'
  ConsoleView = require './views/ConsoleView'
  SetupView   = require './views/SetupView'
  HomeView    = require './views/HomeView'
  GameView    = require './views/GameView'
  LoadingView = require './views/LoadingView'

  gameStates    = require './gameStates'
  pusherWrapper = require './pusherWrapper'

  class extends Backbone.Router
    routes:
      'play/:hash'      : 'play'
      'setup/create'    : 'create'
      'setup/join/:hash': 'join'
      'setup/pool'      : 'pool'
      ''                : 'home'

    initialize: ->
      @consoleView = new ConsoleView()
      $(document.body).append @consoleView.el
      @boardView = new BoardView()
      $(document.body).append @boardView.el

    home: ->
      homeView = new HomeView()
      @setContent homeView.el

    play: (hash) ->
      loadingView = new LoadingView text: 'Loading game...'
      @setContent loadingView.el

      $.get('api/game',
          player_hash: hash
        )
          .done (game) =>
            @_checkGameRender game, loadingView

    pool: ->
      @_setup
        type: 'pool'
      ,
        'Connecting to pool...'

    create: ->
      @_setup
        type: 'create'
      ,
        'Creating game...'

    join: (hash) ->
      @_setup
        type: 'join'
        hash: hash
      ,
        'Joining game...'

    setContent: (html) ->
      @_clear()
      @boardView.$contentContainer.html html

    _checkGameRender: (game, loadingView) ->
      # Loading view should already be visible when calling

      loadingView.setText 'Connecting to websocket...'
      pusherWrapper.connect()
        .done =>
          gameView = new GameView(game)

          switch gameView.game.get('game_state')
            when gameStates.WAITING_FOR_OPPONENT
              loadingView.setText 'Waiting for opponent...'

              gameView.channel.bind 'blue_ready', =>
                @setContent gameView.el
                gameView.channel.unbind 'blue_ready'

            when gameStates.PLAYING
              @setContent gameView.el

    _clear: ->
      @boardView.$contentContainer.empty()

      # Remove all registered callbacks
      @stopListening()

      # Unsubscribe from all channels and unbind all events...
      pusherWrapper.unsubscribeAll()

    _joinPool: (board, loadingView) ->
      # Loading view should already be visible when calling

      pusherWrapper.connect()
        .done =>
          loadingView.setText 'Connected to pool, setting up match...'

          $.post('api/pool/join',
            board: board
            socket_id: pusherWrapper.pusher.connection.socket_id
          )
            .done (game) =>
              loadingView.setText 'In pool, waiting for an opponent...'

    _setup: (setupOptions = {}, loadingText) ->
      setupView = new SetupView(setupOptions)
      @setContent setupView.el

      @listenToOnce setupView, 'ready', (data) =>
        loadingView = new LoadingView text: loadingText
        @setContent loadingView.el

        data.board = JSON.stringify data.board
        if setupOptions.type is 'join'
          data.join_hash = setupOptions.hash

        switch setupOptions.type
          when 'create', 'join'
            $.post("api/#{setupOptions.type}", data)
              .done (game) =>
                @_checkGameRender game, loadingView

                @navigate "play/#{game.player_hash}"

          when 'pool'
            @_joinPool data.board, loadingView
