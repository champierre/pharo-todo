| server store indexHtml reflectHtml todoPackageClasses isResume saveImage |

"=== Check if resuming from a saved image ==="
isResume := Smalltalk globals includesKey: #TodoAppStore.

Stdio stdout
	nextPutAll: (isResume
		ifTrue: [ 'Resuming from saved image - data restored' ]
		ifFalse: [ 'First run - creating fresh store' ]);
	nextPut: Character lf; flush.

isResume ifFalse: [
	"=== Define TodoItem class ==="
	Object subclass: #TodoItem
		instanceVariableNames: 'id title completed createdAt'
		classVariableNames: ''
		package: 'TodoApp'.

	TodoItem compile: 'id ^ id'.
	TodoItem compile: 'id: anInteger id := anInteger'.
	TodoItem compile: 'title ^ title'.
	TodoItem compile: 'title: aString title := aString'.
	TodoItem compile: 'completed ^ completed'.
	TodoItem compile: 'completed: aBoolean completed := aBoolean'.
	TodoItem compile: 'createdAt ^ createdAt'.
	TodoItem compile: 'initialize
		super initialize.
		completed := false.
		createdAt := DateAndTime now'.
	TodoItem compile: 'asDictionary
		^ Dictionary new
			at: ''id'' put: id;
			at: ''title'' put: title;
			at: ''completed'' put: completed;
			at: ''createdAt'' put: createdAt printString;
			yourself'.
	TodoItem class compile: 'title: aString
		^ self new title: aString; yourself'.

	"=== Define TodoStore class ==="
	Object subclass: #TodoStore
		instanceVariableNames: 'items nextId'
		classVariableNames: ''
		package: 'TodoApp'.

	TodoStore compile: 'initialize
		super initialize.
		items := OrderedCollection new.
		nextId := 1'.
	TodoStore compile: 'items ^ items'.
	TodoStore compile: 'addTitle: aString
		| item |
		item := TodoItem title: aString.
		item id: nextId.
		nextId := nextId + 1.
		items add: item.
		^ item'.
	TodoStore compile: 'removeId: anInteger
		items removeAllSuchThat: [ :each | each id = anInteger ]'.
	TodoStore compile: 'toggleId: anInteger
		items
			detect: [ :each | each id = anInteger ]
			ifFound: [ :item | item completed: item completed not ]'.
	TodoStore compile: 'asJsonArray
		^ (items collect: [ :each | each asDictionary ]) asArray'.

	"=== Create store and register in globals ==="
	store := TodoStore new.
	Smalltalk globals at: #TodoAppStore put: store.
] ifTrue: [
	"=== Resume: reuse existing store ==="
	store := Smalltalk globals at: #TodoAppStore.
	Stdio stdout
		nextPutAll: 'Restored ';
		nextPutAll: store items size printString;
		nextPutAll: ' todos from image';
		nextPut: Character lf; flush.
].

"=== Save helper: fork image snapshot after data changes ==="
saveImage := [
	[ (Delay forMilliseconds: 500) wait.
	  Smalltalk snapshot: true andQuit: false.
	  Stdio stdout nextPutAll: 'Image saved'; nextPut: Character lf; flush
	] fork
].

"=== Stop any existing Zinc servers (stale from saved image) ==="
ZnServer managedServers do: [ :s | [ s stop ] on: Error do: [ :e | ] ].

"=== Load HTML files (always reload for latest changes) ==="
indexHtml := '/home/exedev/index.html' asFileReference contents.
reflectHtml := '/home/exedev/reflect.html' asFileReference contents.
todoPackageClasses := { TodoItem. TodoStore }.

server := ZnServer on: 8000.
server maximumEntitySize: 200 * 1024 * 1024. "200MB"
server onRequestRespond: [ :request |
	| path method response |
	path := request uri path.
	(path isEmpty or: [ path first ~= $/ ]) ifTrue: [ path := '/' , path ].
	method := request method.
	response := nil.

	"=== Index page ==="
	(path = '/' and: [ method = 'GET' ]) ifTrue: [
		response := ZnResponse ok: (ZnEntity html: indexHtml)
	].

	"=== GET /api/todos ==="
	(response isNil and: [ path = '/api/todos' and: [ method = 'GET' ] ]) ifTrue: [
		response := ZnResponse ok: (ZnEntity json: (STONJSON toString: store asJsonArray))
	].

	"=== POST /api/todos ==="
	(response isNil and: [ path = '/api/todos' and: [ method = 'POST' ] ]) ifTrue: [ | body title item |
		body := STONJSON fromString: request contents.
		title := body at: 'title' ifAbsent: [ '' ].
		title ifEmpty: [ title := 'Untitled' ].
		item := store addTitle: title.
		saveImage value.
		response := ZnResponse ok: (ZnEntity json: (STONJSON toString: item asDictionary))
	].

	"=== PUT /api/todos/:id (toggle) ==="
	(response isNil and: [ (path beginsWith: '/api/todos/') and: [ method = 'PUT' ] ]) ifTrue: [
		store toggleId: (path copyAfterLast: $/) asInteger.
		saveImage value.
		response := ZnResponse ok: (ZnEntity json: '{"ok":true}')
	].

	"=== DELETE /api/todos/:id ==="
	(response isNil and: [ (path beginsWith: '/api/todos/') and: [ method = 'DELETE' ] ]) ifTrue: [
		store removeId: (path copyAfterLast: $/) asInteger.
		saveImage value.
		response := ZnResponse ok: (ZnEntity json: '{"ok":true}')
	].

	"=== GET /api/image/download - Download image snapshot ==="
	(response isNil and: [ path = '/api/image/download' and: [ method = 'GET' ] ]) ifTrue: [ | imageFile bytes |
		Smalltalk snapshot: true andQuit: false.
		imageFile := '/home/exedev/Pharo-todo.image' asFileReference.
		bytes := imageFile binaryReadStream upToEnd.
		response := ZnResponse ok: (ZnEntity bytes: bytes).
		response headers at: 'Content-Type' put: 'application/octet-stream'.
		response headers at: 'Content-Disposition' put: 'attachment; filename="Pharo-todo.image"'.
	].

	"=== POST /api/image/upload - Upload and restore image ==="
	(response isNil and: [ path = '/api/image/upload' and: [ method = 'POST' ] ]) ifTrue: [ | part bytes dest |
		part := request entity.
		(part isKindOf: ZnMultiPartFormDataEntity)
			ifTrue: [ bytes := (part partNamed: 'image') entity bytes ]
			ifFalse: [ bytes := part bytes ].
		dest := '/home/exedev/Pharo-todo-upload.image' asFileReference.
		dest binaryWriteStream nextPutAll: bytes; close.
		"Replace current image and restart via exit"
		'/home/exedev/Pharo-todo.image' asFileReference delete.
		dest renameTo: 'Pharo-todo.image'.
		response := ZnResponse ok: (ZnEntity json: '{"ok":true,"message":"Image uploaded. Restarting..."}').
		"Schedule restart after response is sent"
		[ (Delay forSeconds: 1) wait. Smalltalk snapshot: false andQuit: true ] fork.
	].

	"=== Reflection page ==="
	(response isNil and: [ path = '/reflect' and: [ method = 'GET' ] ]) ifTrue: [
		response := ZnResponse ok: (ZnEntity html: reflectHtml)
	].

	"=== GET /api/reflect/classes ==="
	(response isNil and: [ path = '/api/reflect/classes' and: [ method = 'GET' ] ]) ifTrue: [ | arr |
		arr := todoPackageClasses collect: [ :cls |
			Dictionary new
				at: 'name' put: cls name;
				at: 'superclass' put: cls superclass name;
				at: 'instanceVariables' put: cls instVarNames asArray;
				at: 'methodCount' put: cls methods size + cls class methods size;
				yourself
		].
		response := ZnResponse ok: (ZnEntity json: (STONJSON toString: arr asArray))
	].

	"=== GET /api/reflect/class/:name ==="
	(response isNil and: [ (path beginsWith: '/api/reflect/class/') and: [ method = 'GET' ] ]) ifTrue: [ | className cls chain instMethods clsMethods info |
		className := path copyAfterLast: $/.
		cls := Smalltalk globals at: className asSymbol ifAbsent: [ nil ].
		cls ifNotNil: [
			chain := OrderedCollection new.
			[ | sc | sc := cls superclass.
			  [ sc notNil ] whileTrue: [ chain add: sc name. sc := sc superclass ]
			] value.
			instMethods := cls methods collect: [ :m |
				Dictionary new
					at: 'selector' put: m selector;
					at: 'protocol' put: m protocol;
					yourself
			].
			clsMethods := cls class methods collect: [ :m |
				Dictionary new
					at: 'selector' put: m selector;
					at: 'protocol' put: m protocol;
					yourself
			].
			info := Dictionary new
				at: 'name' put: cls name;
				at: 'superclass' put: cls superclass name;
				at: 'superclassChain' put: chain asArray;
				at: 'instanceVariables' put: cls instVarNames asArray;
				at: 'classVariables' put: cls classVarNames asArray;
				at: 'package' put: 'TodoApp';
				at: 'instanceMethods' put: instMethods asArray;
				at: 'classMethods' put: clsMethods asArray;
				yourself.
			response := ZnResponse ok: (ZnEntity json: (STONJSON toString: info))
		] ifNil: [
			response := ZnResponse notFound: className
		]
	].

	"=== GET /api/reflect/method/:class/:selector ==="
	(response isNil and: [ (path beginsWith: '/api/reflect/method/') and: [ method = 'GET' ] ]) ifTrue: [ | parts className selName cls side cm info |
		parts := (path allButFirst) substrings: '/'.
		(parts size >= 5) ifTrue: [
			className := parts fourth.
			selName := ('' join: (parts copyFrom: 5 to: parts size)) copyReplaceAll: '%3A' with: ':'.
			side := 'instance'.
			cls := Smalltalk globals at: className asSymbol ifAbsent: [ nil ].
			cls ifNotNil: [
				cm := cls methodDictionary at: selName asSymbol ifAbsent: [ nil ].
				cm ifNil: [
					cm := cls class methodDictionary at: selName asSymbol ifAbsent: [ nil ].
					side := 'class'
				].
				cm ifNotNil: [
					info := Dictionary new
						at: 'class' put: className;
						at: 'selector' put: selName;
						at: 'source' put: cm sourceCode;
						at: 'protocol' put: cm protocol;
						at: 'side' put: side;
						yourself.
					response := ZnResponse ok: (ZnEntity json: (STONJSON toString: info))
				]
			]
		]
	].

	"=== GET /api/reflect/system ==="
	(response isNil and: [ path = '/api/reflect/system' and: [ method = 'GET' ] ]) ifTrue: [ | info |
		info := Dictionary new
			at: 'vmVersion' put: Smalltalk vm version;
			at: 'imageVersion' put: SystemVersion current imageVersionString;
			at: 'totalClasses' put: Smalltalk globals classNames size;
			at: 'totalMethods' put: (todoPackageClasses inject: 0 into: [ :sum :c | sum + c methods size + c class methods size ]);
			at: 'memoryUsage' put: Smalltalk vm memorySize;
			yourself.
		response := ZnResponse ok: (ZnEntity json: (STONJSON toString: info))
	].

	response ifNil: [ response := ZnResponse notFound: path ].
	response
].

server start.
Stdio stdout nextPutAll: 'Pharo TODO server started on port 8000'; nextPut: Character lf; flush.
[ true ] whileTrue: [ (Delay forSeconds: 60) wait ].
