React = require 'react'
_ = require 'underscore'
classNames = require 'classnames'
NotificationStore = require './notifications-store'
{Actions,
 TaskQueue,
 AccountStore,
 NylasSyncStatusStore,
 TaskQueueStatusStore,
 NylasAPI} = require 'nylas-exports'
ActivitySidebarLongPollStore = require './activity-sidebar-long-poll-store'
{TimeoutTransitionGroup, RetinaImg} = require 'nylas-component-kit'

class ActivitySidebar extends React.Component
  @displayName: 'ActivitySidebar'

  @containerRequired: false
  @containerStyles:
    minWidth: 165
    maxWidth: 400

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @_unlisteners = []
    @_unlisteners.push TaskQueueStatusStore.listen @_onDataChanged
    @_unlisteners.push NylasSyncStatusStore.listen @_onDataChanged
    @_unlisteners.push NotificationStore.listen @_onDataChanged
    @_unlisteners.push ActivitySidebarLongPollStore.listen @_onDeltaReceived

  componentWillUnmount: =>
    unlisten() for unlisten in @_unlisteners
    @_workerUnlisten() if @_workerUnlisten

  render: =>
    items = [].concat(@_renderSyncActivityItem(), @_renderNotificationActivityItems(), @_renderTaskActivityItems())

    if @state.receivingDelta
      items.push @_renderDeltaSyncActivityItem()

    names = classNames
      "sidebar-activity": true
      "sidebar-activity-error": error?

    wrapperClass = "sidebar-activity-transition-wrapper "

    if items.length is 0
      wrapperClass += "sidebar-activity-empty"
    else
      inside = <TimeoutTransitionGroup
        className={names}
        leaveTimeout={625}
        enterTimeout={125}
        transitionName="activity-opacity">
        {items}
      </TimeoutTransitionGroup>

    <TimeoutTransitionGroup
      className={wrapperClass}
      leaveTimeout={625}
      enterTimeout={125}
      transitionName="activity-opacity">
        {inside}
    </TimeoutTransitionGroup>

  _renderSyncActivityItem: =>
    count = 0
    fetched = 0
    progress = 0
    incomplete = 0
    error = null

    for acctId, state of @state.sync
      for model, modelState of state
        incomplete += 1 unless modelState.complete
        error ?= modelState.error
        if modelState.count
          count += modelState.count / 1
          fetched += modelState.fetched / 1

    progress = (fetched / count) * 100 if count > 0

    if incomplete is 0
      return []
    else if error
      <div className="item" key="initial-sync">
        <div className="inner">Initial sync encountered an error. Waiting to retry...
          <div className="btn btn-emphasis" onClick={@_onTryAgain}>Try Again</div>
        </div>
      </div>
    else
      <div className="item" key="initial-sync">
        <div className="progress-track">
          <div className="progress" style={width: "#{progress}%"}></div>
        </div>
        <div className="inner">Syncing mail data&hellip;</div>
      </div>

  _renderTaskActivityItems: =>
    summary = {}

    @state.tasks.map (task) ->
      label = task.label?()
      return unless label
      summary[label] ?= 0
      summary[label] += 1

    _.pairs(summary).map ([label, count]) ->
      <div className="item" key={label}>
        <div className="inner">
          {label} <span className="count">({count})</span>
        </div>
      </div>

  _renderDeltaSyncActivityItem: =>
    <div className="item" key="delta-sync-item">
      <div style={padding: "8px 7px 0 10px", float: "left"}>
        <RetinaImg name="sending-spinner.gif" mode={RetinaImg.Mode.ContentPreserve} />
      </div>
      <div className="inner">
        Syncing mail data&hellip;
      </div>
    </div>

  _renderNotificationActivityItems: =>
    @state.notifications.map (notification) ->
      <div className="item" key={notification.id}>
        <div className="inner">
          {notification.message}
        </div>
      </div>

  _onTryAgain: =>
    Actions.retryInitialSync()

  _onDataChanged: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    notifications: NotificationStore.notifications()
    tasks: TaskQueueStatusStore.queue()
    sync: NylasSyncStatusStore.state()

  _onDeltaReceived: (countDeltas) =>
    tooSmallForNotification = countDeltas <= 10
    return if tooSmallForNotification

    if @_timeoutId
      clearTimeout @_timeoutId

    @_timeoutId = setTimeout(( =>
      delete @_timeoutId
      @setState receivingDelta: false
    ), 30000)

    @setState receivingDelta: true


module.exports = ActivitySidebar
