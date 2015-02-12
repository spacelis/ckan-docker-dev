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
    FS.statSync path
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
        console.log "#{chalk.red "[Error]"} #{proc}: The action is not defined."
        process.exit -2
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
        reg[@name] = @

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

findDockerTag = (path) ->
  TAGPTN = '-- TAG:'
  content = FS.readFileSync(path).split('\n')
  for l in content
    pos = l.indexof(TAGPTN) 
    if pos >= 0
      return l.slice(pos + TAGPTN)

dockerBuildImage = (path) ->
  findDockerTag path + "/Dockerfile"
  launcher "docker", ["build", "-t", tag, '.'],
    cwd: Path.resolve path

gitClone = (urls, path) ->
  for url in urls
    try 
      console.log "#{chalk.green "[GIT]"} Try pulling from #{url}"
      launcher "git", ["clone", url, path]
      console.log "#{chalk.green "[GIT]"} Cloned into #{path} "
    catch
      null


# -------------- Task Utility
#
MakingImage = (name, path, dependencies, meta) ->
  meta ?= {}
  meta['path'] = Path.resolve path
  new Procedure 
    model: 'MakingImage'
    type: 'major'
    name: name
    description: "Build the image from #{ path }"
    target: -> timestampChanged [ getImageMTime tag ], _.map normalFiles path, _timestamp
    action: -> dockerBuildImage meta['path']
    dependencies: dependencies
    meta: meta

ImageFrom = (obj, dependencies, options) ->
  if not _.isString obj
    path = obj.getMeta 'path'
    dependencies ?= []
    dependencies.push(obj.name)
  else
    path = obj
  MakingImage "img-" + (Path.basename path), path, dependencies
  

GitCache = (name, urls, path) ->
  path ?= name
  new Procedure 
    model: 'GitCache'
    type: 'major'
    name: name
    description: "Cloning the code repo from #{urls}"
    target: -> isDir Path.resolve path
    action: -> gitClone urls, path
    meta:
      path: path


FigUp = (name, path) ->
  new Procedure
    model: 'FigUp'
    type: 'major'
    name: name, 
    description: "Fig up at #{path}",
    action: -> 
      launcher "fig", ["up"],
        cwd: path
    meta:
      path: path

# -------------- Definition of Global Tasks


task "help", "Print more details about the Cakefile", ->
  ProcRegistry.info()

# -------------- Definition of Tasks


ckanbase = ImageFrom (GitCache 'ckan_docker_base', 
    ['https://github.com/spacelis/ckan-docker-base.git'], 
    '../ckan-docker-base'), [],
  prefix: 'spacelis'
  suffix: 'cake'

GitCache('ckan', ['../ckan-docker-base/.git', 'https://github.com/spacelis/ckan'])

new Procedure 
  name: 'build'
  type: 'major'
  description: "Build all images"
  dependencies: [ckanbase.name]


# plainTask 'debug3', 'check the code',
#   target: (-> console.log getImageMTime 'testbase'; true)
#   action: (-> console.log 'Running consequent3')
#
# plainTask 'debug2', 'check the code',
#   target: (-> console.log 'Checking target2'; true)
#   action: (-> console.log 'Running consequent2')
#
# plainTask 'debug', 'check the code',
#   target: (-> console.log getImageMTime('spacelis/base4ckan'); false)
#   action: (-> console.log 'Running consequent')
#   dependencies: ['debug2']
