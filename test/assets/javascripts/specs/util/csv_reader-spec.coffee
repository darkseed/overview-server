require [
  'util/csv_reader'
], (CsvReader) ->
  describe 'util/csv_reader', ->
    describe 'CsvReader', ->
      #string_as_uint8array = (s) ->
      #  ret = new Uint8Array(s.length)
      #  ret[i] = s.charCodeAt(i) for i in [0...s.length]
      #  ret

      in_read_callback = (string, callback) ->
        # Jasmine's async test framework crashes with jstd. Work around it.
        reader = new CsvReader()
        reader._handle_loadend(2, null, string)
        callback(reader)

        #buffer = string_as_uint8array(utf8ish_string)
        #reader = new CsvReader()

        #runs ->
        #  blob = new Blob([buffer])
        #  reader.read(blob, 'utf-8')

        #waitsFor(->
        #  reader.readyState == 2 # DONE
        #, "the reader should not stall", 1000) # 1s

        #runs -> callback(reader)

      expecting_result = (s, callback) ->
        in_read_callback s, (reader) ->
          expect(reader.error).toBeNull()
          callback(reader.result, reader)

      expecting_syntax_error = (s, callback) ->
        in_read_callback s, (reader) ->
          expect(reader.error.name).toEqual('SyntaxError')
          callback(reader.error, reader)

      it 'should set "text" when CSV is invalid', ->
        expecting_syntax_error "a\"b", (error, reader) ->
          expect(reader.text).toEqual("a\"b")

      it 'should set line and column of SyntaxError', ->
        expecting_syntax_error "a\"b", (error) ->
          expect(error.line).toEqual(1)
          expect(error.column).toEqual(2)

      it 'should throw an error when a single quote is in the middle of a string', ->
        expecting_syntax_error "a\"b", (error) ->
          expect(error.line).toEqual(1)
          expect(error.column).toEqual(2)

      it 'should throw an error when a quoted string is in the middle of a string', ->
        expecting_syntax_error "foo,bar\r\nfoo2\"blah\",bar2", (error) ->
          expect(error.line).toEqual(2)
          expect(error.column).toEqual(5)

      it 'should parse into the "result" object', ->
        expecting_result "foo,bar\r\nbaz1,baz2\r\nbaz3,baz4", (result) ->
          expect(result).toEqual({
            header: [ 'foo', 'bar' ],
            records: [ [ 'baz1', 'baz2' ], [ 'baz3', 'baz4' ] ]
          })

      it 'should parse an empty-string value', ->
        expecting_result "foo,,bar", (result) ->
          expect(result.header).toEqual([ 'foo', '', 'bar' ])

      it 'should parse a quoted empty-string value', ->
        expecting_result "foo,\"\",bar", (result) ->
          expect(result.header).toEqual([ 'foo', '', 'bar' ])

      it 'should parse a quotation mark', ->
        expecting_result "foo,\"a\"\"b\",bar", (result) ->
          expect(result.header).toEqual([ 'foo', 'a"b', 'bar' ])

      it 'should allow a truncated string at the end', ->
        expecting_result 'foo,bar\r\na,\"b', (result) ->
          expect(result.records).toEqual([[ 'a', 'b' ]])
