casper = require \casper .create()
uuid = require \node-uuid

casper.start "http://localhost/user/login", ->
  @fill "form[action='/login_generic?came_from=/user/logged_in']",
    login: \ckan,
    password: \ckan,
    true

casper.thenOpen "http://localhost/dataset/new", ->
  @echo @getCurrentUrl!
  @sendKeys 'form#dataset-edit input#field-title', "Census UK 2011 (#{ uuid.v4() })"
  @echo @evaluate ->
    $ '.slug-preview-value' .text()

casper.then ->
  @click 'form#dataset-edit button[type="submit"]'

casper.then ->
  @echo @getCurrentUrl!
  @fill 'form#resource-edit',
    upload: "./test_data/Workplace population.csv"
    name: "Workplace Population (#{ uuid.v4() })"
    format: "CSV"
  @click 'button[value="go-metadata"]'

casper.then ->
  @echo @evaluate ->
    $ 'a.heading' .href()

casper.run()
