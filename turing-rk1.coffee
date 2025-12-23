deviceTypesCommon = require '@resin.io/device-types/common'
{ networkOptions, commonImg, instructions } = deviceTypesCommon

module.exports =
	version: 1
	slug: 'turing-rk1'
	name: 'Turing RK1'
	arch: 'aarch64'
	state: 'new'

	instructions: commonImg.instructions

	gettingStartedLink:
		windows: 'https://www.balena.io/docs/learn/getting-started/turing-rk1/nodejs/'
		osx: 'https://www.balena.io/docs/learn/getting-started/turing-rk1/nodejs/'
		linux: 'https://www.balena.io/docs/learn/getting-started/turing-rk1/nodejs/'

	options: [ networkOptions.group ]

	yocto:
		machine: 'turing-rk1'
		image: 'balena-image'
		fstype: 'balenaos-img'
		version: 'yocto-scarthgap'
		deployArtifact: 'balena-image-turing-rk1.balenaos-img'
		compressed: true

	configuration:
		config:
			partition: 4
			path: '/config.json'

	initialization: commonImg.initialization
