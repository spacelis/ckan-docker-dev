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

_uid = new UUIDPool()

path2name = (path) ->
  full = Path.resolve path
  n1 = (Path.basename full).split('.')[0].trim()
  if n1.length is 0
    Path.basename Path.dirname full


_flatmap = (list, iteree) ->
  _.reduce (_.map list, iteree), ((x, y) -> x.concat(y)), []

_timestamp = (d) ->
  FS.statSync(d).mtime.getTime

timestampChanged = (targets, sources) ->
  if (_.every targets, (x) -> x > 0)
    (_.min sources) > (_.max targets)
  else
    false

fileChanged = (targets, sources) ->
  timestampChanged (_.map targets, _timestamp), (_.map sources, _timestamp)
  
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
    console.log "#{ proc }: Starting Task"
    console.log "#{ proc }: Checking Target"
    {target, action, dependencies} = reg[proc]
    if target?()
      console.log "#{ proc }: Target Holds ... SKIP"
    else
      if dependencies?.length > 0
        console.log "#{ proc }: Depending on #{ dependencies }"
        for proc in dependencies
          _runProcedure reg, proc

      console.log "#{ proc }: The action start"
      if action?
        action()
        console.log "#{ proc }: The action complete"
      else
        console.log "#{chalk.yellow "[Warn]"} #{proc}: The action is not defined."
      if !reg[proc].target?()
        console.log "#{ chalk.red "[Error]"} #{ proc }: The target cannot be ensured through the action"
        process.exit -1

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
  console.log "#{chalk.green "Exec [#{options?.cwd ? ""}]"}: #{cmd} #{ args.join ' '}"
  options ?= {}
  options.stdio ?= [0, 0, 0]
  cmd = which(cmd) if which
  app = spawnSync cmd, args, options


# ------------- project specific

getImageMTime = (tag) ->
  imageId = (execSync "bash -c 'docker history --no-trunc -q #{tag} | head -1'").toString()
  if !(imageId.length is 0)
    parseInt execSync "bash -c 'sudo stat -c %Y /var/lib/docker/graph/#{ String imageId }'"
  else
    -1

gitUpToDate = (path) ->
  (execSync "bash -c 'cd #{path}; git fetch --dry-run 2>&1'").toString() is ""

findDockerTag = (path) ->
  TAGPTN = '--TAG:'
  content = FS.readFileSync(path).toString().split('\n')
  for l in content
    pos = l.indexOf(TAGPTN) 
    if pos >= 0
      return l.slice(pos + TAGPTN.length).trim()
  null

dockerBuildImage = (dockerfile) ->
  tag = findDockerTag dockerfile
  launcher "docker", ["build", "-t", tag, '.'],
    cwd: Path.dirname dockerfile

gitClone = (path, urls) ->
  for url in urls
    try 
      console.log "#{chalk.green "[GIT]"} Try pulling from #{url}"
      launcher "git", ["clone", url, path]
      console.log "#{chalk.green "[GIT]"} Cloned into #{path} "
    catch
      null

gitPull = (path) ->
  launcher "git", ["pull"],
    cwd: path

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
        tag = findDockerTag meta.dockerfile
        timestampChanged [ getImageMTime tag ], _.map normalFiles path, _timestamp
      catch
        false
    action: -> dockerBuildImage meta.dockerfile
    dependencies: dependencies
    meta: meta

ImageFrom = (obj, dependencies, name, options) ->
  if not _.isString obj
    path = obj.getMeta 'path'
    dependencies ?= []
    dependencies.push(obj.name)
  else
    path = obj
  MakingImage name ? "img-" + (Path.basename path), path, dependencies
  

GitCache = (urls, name, obj) ->
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
    target: -> (isDir path) and (gitUpToDate path)
    action: -> 
      if isDir path
        gitPull path
      else
        gitClone path, urls
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

# -------------- Definition of Global Tasks


task "help", "Print more details about the Cakefile", ->
  ProcRegistry.info()

# -------------- Definition of Tasks


ckanbaseimg = ImageFrom (GitCache ['../ckan-docker-base/.git', 
                                   'https://github.com/spacelis/ckan-docker-base.git'], 
  'build/ckan-docker-base', 'ckan-docker-base')

ckandevimg = ImageFrom (GitCache [".git"], 'ckan-docker-dev', 'build/ckan-docker-dev')

build = new Procedure 
  name: 'build'
  type: 'major'
  description: "Build all images"
  dependencies: [ckandevimg]

FigUp 'up', '.', [build,
  GitCache ["../ckan/.git"], null, 'ckan-docker-dev'
  GitCache ["../ckan-datapusher-service/.git"], null, 'ckan-docker-dev'
  GitCache ["../ckan-service-provider/.git"], null, 'ckan-docker-dev'
  ]

# plainTask 'debug3', 'check the code',
#   target: (-> console.log getImageMTime 'testbase'; true)
#   action: (-> console.log 'Running consequent3')
#
# plainTask 'debug2', 'check the code',
#   target: (-> console.log 'Checking target2'; true)
#   action: (-> console.log 'Running consequent2')
#
# task 'debug', 'check the code', -> 
#   console.log path2name '.git'
