| server store indexHtml |

store := Dictionary new
	at: 'items' put: OrderedCollection new;
	at: 'nextId' put: 1;
	yourself.

indexHtml := '/home/exedev/index.html' asFileReference contents.

server := ZnServer on: 8000.
server onRequestRespond: [ :request |
	| path method response |
	path := request uri path.
	"Normalize: ensure leading slash"
	(path isEmpty or: [ (path first) ~= $/ ]) ifTrue: [ path := '/' , path ].
	method := request method.
	response := nil.

	(path = '/' and: [ method = 'GET' ]) ifTrue: [
		response := ZnResponse ok: (ZnEntity html: indexHtml)
	].

	(response isNil and: [ path = '/api/todos' and: [ method = 'GET' ] ]) ifTrue: [ | json arr |
		arr := (store at: 'items') collect: [ :each |
			Dictionary new
				at: 'id' put: (each at: 'id');
				at: 'title' put: (each at: 'title');
				at: 'completed' put: (each at: 'completed');
				yourself
		].
		json := STONJSON toString: arr asArray.
		response := ZnResponse ok: (ZnEntity json: json)
	].

	(response isNil and: [ path = '/api/todos' and: [ method = 'POST' ] ]) ifTrue: [ | body title item id json |
		body := STONJSON fromString: request contents.
		title := body at: 'title' ifAbsent: [ '' ].
		title ifEmpty: [ title := 'Untitled' ].
		id := store at: 'nextId'.
		store at: 'nextId' put: id + 1.
		item := Dictionary new
			at: 'id' put: id;
			at: 'title' put: title;
			at: 'completed' put: false;
			yourself.
		(store at: 'items') add: item.
		json := STONJSON toString: item.
		response := ZnResponse ok: (ZnEntity json: json)
	].

	(response isNil and: [ (path beginsWith: '/api/todos/') and: [ method = 'PUT' ] ]) ifTrue: [ | id |
		id := (path copyAfterLast: $/) asInteger.
		(store at: 'items') do: [ :each |
			(each at: 'id') = id ifTrue: [
				each at: 'completed' put: (each at: 'completed') not
			]
		].
		response := ZnResponse ok: (ZnEntity json: '{"ok":true}')
	].

	(response isNil and: [ (path beginsWith: '/api/todos/') and: [ method = 'DELETE' ] ]) ifTrue: [ | id |
		id := (path copyAfterLast: $/) asInteger.
		(store at: 'items') removeAllSuchThat: [ :each | (each at: 'id') = id ].
		response := ZnResponse ok: (ZnEntity json: '{"ok":true}')
	].

	response ifNil: [ response := ZnResponse notFound: path ].
	response
].

server start.

Stdio stdout nextPutAll: 'Pharo TODO server started on port 8000'; nextPut: Character lf; flush.

[ true ] whileTrue: [ (Delay forSeconds: 60) wait ].
