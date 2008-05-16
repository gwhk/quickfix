require "rexml/document"

class DataDictionary
	def initialize( major, minor )
		@f = File.new( "FIX#{major}#{minor}.out.xml", File::CREAT|File::TRUNC|File::RDWR )
		@major = major
		@minor = minor

		directory = "FIX.#{major}.#{minor}"
		@fieldsDoc = REXML::Document.new( File.new( "#{directory}/Fields.xml" ) )
		@enumsDoc = REXML::Document.new( File.new( "#{directory}/Enums.xml" ) )
		@msgContentsDoc = REXML::Document.new( File.new("#{directory}/MsgContents.xml") )
		@msgTypeDoc = REXML::Document.new( File.new("#{directory}/MsgType.xml") )
		@componentsDoc =  REXML::Document.new( File.new("#{directory}/Components.xml") )

		@specDoc = REXML::Document.new()

		parseDictionary
		printDictionary
	end

	def tagShouldBeSkipped( tag )
		return true if tag == 101
		return true if tag == 261
		return true if tag == 809
	end

	def toFieldName( fieldName )
		fieldName.split(" (")[0].split("(")[0].strip
	end

	def toDescription( description )
		return "" if description == nil
		old = description.clone
		description.upcase!
		description = description.split("(")[0]
		description = description.split(",")[0]
		return "" if description == nil
		description.strip!
		description.gsub!('+ ', '+')
		description.gsub!(' ', '_')
		description.gsub!('-', '_')
		description.gsub!('/', '_')
		description.gsub!('+', 'PLUS')
		description = description.split("___")[0]
		return description
	end

	def toType( type )
		case type
			when "CHAR"
				return "STRING"
			else
				return type
		end
		end

	def parseFields
		@tagToField = Hash.new

		@fieldsDoc.elements["dataroot"].elements.each("Fields") { |fieldsElement|
			tag = fieldsElement.elements["Tag"].text.to_i
			next if tagShouldBeSkipped( tag )

			fieldName = toFieldName(fieldsElement.elements["FieldName"].text)
			type = fieldsElement.elements["Type"].text
			next if type == nil
			type.upcase!

			fieldHash = Hash.new
			fieldHash[ "type" ] = toType( type )
			fieldHash[ "fieldName" ] = fieldName
			@tagToField[ tag ] = fieldHash
		}
	end

	def parseEnums
		@tagToEnum = Hash.new
		enumHash = Hash.new
		lastTag = 0

		@enumsDoc.elements["dataroot"].elements.each("Enums") { |enumsElement|
			tag = enumsElement.elements["Tag"].text.to_i
			next if tagShouldBeSkipped( tag )

			enum = enumsElement.elements["Enum"]
			description = toDescription(enumsElement.elements["Description"].text)

			enumHash = Hash.new if lastTag != tag

			enumHash[ enum.text ] = description
			@tagToEnum[ tag ] = enumHash

			lastTag = tag
		}
	end

	def parseMsgType
		@msgIdToMsgType = Hash.new

		@msgTypeDoc.elements["dataroot"].elements.each("MsgType") { |msgTypeElement|
			msgId = msgTypeElement.elements["MsgID"].text.to_i
			msgType = msgTypeElement.elements["MsgType"].text
			messageName = msgTypeElement.elements["MessageName"].text
			componentType = msgTypeElement.elements["ComponentType"].text
			category = msgTypeElement.elements["Category"].text

			category = category == "Session" ? "admin" : "app"

			msgTypeHash = Hash.new
 			msgTypeHash[ "msgtype" ] = msgType
			msgTypeHash[ "name" ] = messageName
			msgTypeHash[ "msgcat" ] = category
			@msgIdToMsgType[ msgId ] = msgTypeHash
		}
	end

	def parseDictionary
		parseFields
		parseEnums
		parseMsgType
	end

	def printVersion
		return @specDoc.add_element( "fix", { "major" => @major.to_s, "minor" => @minor.to_s } )
	end

	def printFields
		@fieldsElement = @fixElement.add_element( "fields" )
		@tagToField.sort.each { |tag, fieldHash|
			type = fieldHash[ "type" ]
			fieldName = fieldHash[ "fieldName" ]
			fieldElement = @fieldsElement.add_element( "field", { "field" => tag.to_s, "name" => fieldName, "type" => type } )
			printEnums( fieldElement, tag )
		}
	end

	def printEnums( fieldElement, tag )
		return if !@tagToEnum.has_key?( tag )

		enumHash = @tagToEnum[ tag ]
		isBool = (enumHash.size == 2 && enumHash.has_key?("Y") && enumHash.has_key?("N"))

 		enumHash.sort.each { |enum, description|
			description = "YES" if isBool && enum == "Y"
			description = "NO" if isBool && enum == "N"
			fieldElement.add_element( "value", { "enum" => enum, "description" => description } )
		}
	end

	def printMessages
		messagesElement = @fixElement.add_element( "messages" )
		@msgIdToMsgType.sort.each { |msgId, msgTypeHash|
			name = msgTypeHash[ "name" ]
			msgtype = msgTypeHash[ "msgtype" ]
			msgcat = msgTypeHash[ "msgcat" ]
			messagesElement.add_element( "message", { "name" => name, "msgtype" => msgtype, "msgcat" => msgcat } )
		}
	end

	def printDictionary
		@fixElement = printVersion
		printFields
		printMessages
		@specDoc.write( @f, 1, false, true )
	end
end

DataDictionary.new( 4, 2 )