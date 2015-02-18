# ------------ imports
FS = require 'fs'
{print} = require 'util'
{spawnSync, execSync} = require 'child_process'
_ = require 'underscore'
Path = require 'path'
chalk = require 'chalk'

try
  which = require('which').sync
catch err
  if process.platform.match(/^win/)?
    console.log "#{chalk.yellow "WARNING"}: the which module is required for windows\ntry: npm install which"
  which = null

# ------------ Utility Functions
#

class UUIDPool
  class UUID
    constructor: (@prefix, seed) ->
      @seed = seed ? 0

    next: ->
      "#{@prefix}-#{@seed++}"

  constructor: ->
    @pool = {}

  get: (prefix) ->
    if @pool[prefix]?
      @pool[prefix]
    else
      @pool[prefix] = new UUID prefix

_loginfo = (msg) ->
  console.log "#{chalk.blue "[INFO]"} #{msg}"

_logwarn = (msg) ->
  console.log "#{chalk.yellow "[WARN]"} #{msg}"

_logerr = (msg) ->
  console.log "#{chalk.bgRed "[Error]"} #{msg}"

_logok = (msg) ->
  console.log "#{chalk.white "[OK]"} #{msg}"

_logexec = (msg) ->
  console.log "#{chalk.green "[Exec]"} #{msg}"

_debug = (obj) ->
  console.log "#{chalk.black.bgCyan "[Debug]"} #{obj}"
  obj

exec = (bashcmd, cwd) ->
  output = (execSync "bash -c '#{bashcmd}'", cwd: cwd).toString().split '\n' ? []
  if output.length is 1 and output[0].trim() is ""
    []
  else
    _.map output, (s) -> s.trim()

_uid = new UUIDPool()

path2name = (path) ->
  full = Path.resolve path
  n1 = (Path.basename full).split('.')[0].trim()
  if n1.length is 0
    Path.basename Path.dirname full


_flatmap = (list, iteree) ->
  _.reduce (_.map list, iteree), ((x, y) -> x.concat(y)), []

_timestamp = (d) ->
  FS.statSync(d).mtime.getTime(d) / 1000

timestampUpToDate = (targets, sources) ->
  if (_.every targets, (x) -> x > 0) and (_.every sources, (x) -> x > 0)
    (_.min targets) >= (_.max sources)
  else
    false

fileUpToDate = (targets, sources) ->
  timestampUpToDate (_.map targets, _timestamp), (_.map sources, _timestamp)

allFiles = (path) ->
  try
    if (FS.statSync path)?.isDirectory()
      [ path ].concat (_flatmap _.map((FS.readdirSync path), ((x) -> "#{path}/#{x}")), allFiles)
    else
      [ path ]
  catch
    []

normalFiles = (path) ->
  _.filter (allFiles path), (p) -> p.indexOf('/.', 1) < 1


isDir = (path) ->
  try
    (FS.statSync path).isDirectory()
  catch
    false

isFile = (path) ->
  try
    (FS.statSync path).isFile()
  catch
    false
# ------------- Task management
#
###
// {'task1': {'dependencies': ['task_x', 'task_y'], 'target': function(), 'action': function() }}
###



class ProcedureRegistry


  constructor: (@name) ->
    @_reg = {}

  _runProcedure = (reg, proc) ->
    _loginfo "#{ proc }: Starting Task"
    _loginfo "#{ proc }: Checking Target"
    {target, action, dependencies, meta} = reg[proc]

    if dependencies?.length > 0
      _loginfo "#{ proc }: Depending on #{ dependencies }"
      for pr in dependencies
        _runProcedure reg, pr

    if target?()
      _loginfo "#{ proc }: Target Holds ... SKIP"
    else
      if action?
        _loginfo "#{ proc }: The action start"
        action()
        if ! meta?._supress_no_target?
          if !target?
            _logwarn "#{proc}: No target ensure"
          else if !target?()
            _logerr "#{ proc }: The target cannot be ensured through the action"
            process.exit -1
        _logok "#{ proc }: The action complete"
      else if ! meta?._supress_no_action?
        _logwarn "#{proc}: The action is not defined"

  getProcedure: (name) ->
    @_reg[name]

  allNames: () ->
    _.keys(@_reg)

  size: () ->
    @allNames().length

  getProcedureClass: ()->
    reg = @._reg
    class _Procedure

      constructor: (options) ->
        {@type, @model, @name, @description, @target, @action, @dependencies, @meta} = options
        task @name, @description, ->
          _runProcedure(reg, @name)
        @dependencies = _.map @dependencies, (d) -> if _.isString d then d else d.getName()
        reg[@name] = @

      getName: () ->
        @name

      getMeta: (key) ->
        try
          @meta[key]
        catch
          null

  info: () ->
    for name in @allNames()
      pr = @getProcedure name
      if pr.type is 'major'
        console.log """
          #{chalk.green name} : #{chalk.blue pr.dependencies ? ''}
            #{pr.description}
        """
    console.log """
      -----------
      Total Procedure#{if @size() > 0 then "s" else ""}: #{@size()}
      """


ProcRegistry = new ProcedureRegistry "root"
Procedure = ProcRegistry.getProcedureClass()




launcher = (cmd, args, options) ->
  _logexec "[#{options?.cwd ? ""}]: #{cmd} #{ args.join ' '}"
  options ?= {}
  options.stdio ?= [0, 0, 0]
  cmd = which(cmd) if which
  app = spawnSync cmd, args, options
  if app.status != 0
    _logerr "Cmd returned #{app.status} #{cmd} #{args.join ' '}"
    process.exit -1


# ------------- project specific

Docker = (->
  imageByTag = (tag) ->
    try
      imageId = (exec "docker history --no-trunc -q #{tag}")[0]
      "/var/lib/docker/graph/#{ imageId }"
    catch
      null

  imageMTime = (tag) ->
    try
      image = imageByTag tag
      if image?
        _loginfo "Checking the image ..."
        parseInt exec "sudo stat -c %Y #{image}"
      else
        throw new Error("Image not found")
    catch
      -1

  determineTag = (path) ->
    TAGPTN = '--TAG:'
    content = FS.readFileSync(path).toString().split('\n')
    for l in content
      pos = l.indexOf(TAGPTN)
      if pos >= 0
        return l.slice(pos + TAGPTN.length).trim()
    null

  buildImage = (dockerfile) ->
    tag = determineTag dockerfile
    launcher "docker", ["build", "-t", tag, '.'],
      cwd: Path.dirname dockerfile

  clearImages = ->
    _.each (exec "docker images -q --no-trunc --filter 'dangling=true'"), (i) ->
      try
        if i?.length > 0
          _loginfo "Deleting image #{i}"
          exec "docker rmi #{i}"

  cleanContainers = ->
    _.each (exec "docker ps -qf 'status=exited' --no-trunc"), (i) ->
      try
        if i?.length > 0
          _loginfo "Deleting container #{i}"
          exec "docker rm #{i}"


  new Procedure
    model: "Docker"
    type: "major"
    name: "rmi",
    description: "Clear non-tagged dock images (most of time intermediate images)"
    action: ->
      clearImages()

  new Procedure
    model: "Docker"
    type: "major"
    name: "rm",
    description: "Clear non-tagged dock images (most of time intermediate images)"
    action: ->
      cleanContainers()


  imageByTag: imageByTag,
  imageMTime: imageMTime,
  determineTag: determineTag,
  buildImage: buildImage
)()

Git = (->

  isUpToDate = (path) ->
    (exec "cd #{path}; git fetch --dry-run 2>&1").length is 0

  clone = (path, urls, branch) ->
    for url in urls
      try
        launcher "git", ["clone", "-b", branch, url, path]
        _logok "Cloned into #{path} "
      catch
        null

  pull = (path) ->
    launcher "git", ["pull"],
      cwd: path

  isUpToDate: isUpToDate,
  clone: clone,
  pull: pull
)()
# -------------- Task Utility
#
MakingImage = (name, path, dependencies, meta) ->
  meta ?= {}
  meta.path = Path.resolve path
  meta.dockerfile = meta.path + "/Dockerfile"
  new Procedure
    model: 'MakingImage'
    type: 'major'
    name: name
    description: "Build the image from #{ path }"
    target: ->
      try
        tag = Docker.determineTag meta.dockerfile
        timestampUpToDate [ Docker.imageMTime tag ], _.map (normalFiles path), _timestamp
      catch
        false
    action: ->
      Docker.buildImage meta.dockerfile
      image = Docker.imageByTag Docker.determineTag meta.dockerfile
      _loginfo "Checking the image ..."
      exec "sudo touch #{image}"
    dependencies: dependencies
    meta: meta

ImageFrom = (obj, dependencies, name, options) ->
  if not _.isString obj
    path = obj.getMeta 'path'
    dependencies ?= []
    dependencies.push(obj.name)
  else
    path = obj
  MakingImage name ? 'img-' + (Path.basename path), path, dependencies


GitCache = (urls, name, obj, branch) ->
  branch ?= 'master'
  name ?= path2name urls[0]
  obj ?= name
  if _.isString obj
    path = Path.resolve obj
  else
    path = Path.resolve "#{(obj.getMeta 'path')}/#{name}"
  new Procedure
    model: 'GitCache'
    type: 'major'
    name: name
    description: "Cloning the code repo from #{urls} to #{path}"
    target: -> (isDir path) and (Git.isUpToDate path)
    action: ->
      if isDir path
        Git.pull path
      else
        Git.clone path, urls, branch
    meta:
      path: path


FigUp = (name, path, dependencies) ->
  new Procedure
    model: 'FigUp'
    type: 'major'
    name: name,
    description: "Fig up at #{path}"
    dependencies: dependencies
    action: ->
      launcher "fig", ["up"],
        cwd: path
    meta:
      path: path
      _supress_no_target: true


FigClean = (path, name) ->
  name ?= 'figclean'
  new Procedure
    model: 'FigClean'
    type: 'major'
    name: name,
    description: "Clean the container, volumes created by FigUp"
    action: ->
      exec 'yes 2> /dev/null | fig rm', path
      _loginfo "Removing the volumes ..."
      exec 'sudo `which clear_docker_volumes` 2>&1', path
    meta:
      path: path
      _supress_no_target: true

# -------------- Definition of Global Tasks


task "help", "Print more details about the Cakefile", ->
  ProcRegistry.info()

# -------------- Definition of Tasks


ckanbaseimg = ImageFrom (GitCache ['../ckan-docker-base/.git',
                                   'https://github.com/spacelis/ckan-docker-base.git'],
  'build/ckan-docker-base', 'ckan-docker-base')

ckandevimg = ImageFrom (GitCache [".git"], 'ckan-docker-dev', 'build/ckan-docker-dev')

ckansolrimg = ImageFrom "./docker-solr"

build = new Procedure
  name: 'build'
  type: 'major'
  description: "Build all images"
  dependencies: [ckandevimg]
  meta:
    _supress_no_target: true
    _supress_no_action: true

FigUp 'up', '.', [build,
  GitCache ["../ckan/.git"], null, 'ckan-docker-dev'
  GitCache ["../ckan-datapusher-service/.git"], null, 'ckan-docker-dev'
  GitCache ["../ckan-service-provider/.git"], null, 'ckan-docker-dev'
  ]

FigClean '.'
# plainTask 'debug3', 'check the code',
#   target: (-> console.log imageMTime 'testbase'; true)
#   action: (-> console.log 'Running consequent3')
#
# plainTask 'debug2', 'check the code',
#   target: (-> console.log 'Checking target2'; true)
#   action: (-> console.log 'Running consequent2')
#
# task 'debug', 'check the code', ->
#   console.log path2name '.git'
