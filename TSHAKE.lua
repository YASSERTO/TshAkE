
--[[                                -.-

--]]

serpent = require('serpent')
serp = require 'serpent'.block
http = require("socket.http")
https = require("ssl.https")
http.TIMEOUT = 10
lgi = require ('lgi')
KOKE=dofile('utils.lua')
json=dofile('json.lua')
JSON = (loadfile  "./libs/dkjson.lua")()
redis = (loadfile "./libs/JSON.lua")()
redis = (loadfile "./libs/redis.lua")()
database = Redis.connect('127.0.0.1', 6379)
notify = lgi.require('Notify')
tdcli = dofile('tdcli.lua')
notify.init ("Telegram updates")
sudos = dofile('sudo.lua')
chats = {}
day = 86400
  -----------------------------------------------------------------------------------------------
                                     -- start functions --
  -----------------------------------------------------------------------------------------------
function is_sudo(msg)
  local var = false
  for k,v in pairs(sudo_users) do
    if msg.sender_user_id_ == v then
      var = true
    end
  end
  return var
end
-----------------------------------------------------------------------------------------------
function is_admin(user_id)
    local var = false
	local hashs =  'bot:admins:'
    local admin = database:sismember(hashs, user_id)
	 if admin then
	    var = true
	 end
  for k,v in pairs(sudo_users) do
    if user_id == v then
      var = true
    end
  end
    return var
end
-----------------------------------------------------------------------------------------------
function is_vip_group(gp_id)
    local var = false
	local hashs =  'bot:vipgp:'
    local vip = database:sismember(hashs, gp_id)
	 if vip then
	    var = true
	 end
    return var
end
-----------------------------------------------------------------------------------------------
function is_owner(user_id, chat_id)
    local var = false
    local hash =  'bot:owners:'..chat_id
    local owner = database:sismember(hash, user_id)
	local hashs =  'bot:admins:'
    local admin = database:sismember(hashs, user_id)
	 if owner then
	    var = true
	 end
	 if admin then
	    var = true
	 end
    for k,v in pairs(sudo_users) do
    if user_id == v then
      var = true
    end
	end
    return var
end

-----------------------------------------------------------------------------------------------
function is_mod(user_id, chat_id)
    local var = false
    local hash =  'bot:mods:'..chat_id
    local mod = database:sismember(hash, user_id)
	local hashs =  'bot:admins:'
    local admin = database:sismember(hashs, user_id)
	local hashss =  'bot:owners:'..chat_id
    local owner = database:sismember(hashss, user_id)
	 if mod then
	    var = true
	 end
	 if owner then
	    var = true
	 end
	 if admin then
	    var = true
	 end
    for k,v in pairs(sudo_users) do
    if user_id == v then
      var = true
    end
	end
    return var
end
-----------------------------------------------------------------------------------------------
function is_banned(user_id, chat_id)
    local var = false
	local hash = 'bot:banned:'..chat_id
    local banned = database:sismember(hash, user_id)
	 if banned then
	    var = true
	 end
    return var
end

function is_gbanned(user_id)
  local var = false
  local hash = 'bot:gbanned:'
  local banned = database:sismember(hash, user_id)
  if banned then
    var = true
  end
  return var
end
-----------------------------------------------------------------------------------------------
function is_muted(user_id, chat_id)
    local var = false
	local hash = 'bot:muted:'..chat_id
    local banned = database:sismember(hash, user_id)
	 if banned then
	    var = true
	 end
    return var
end

function is_gmuted(user_id, chat_id)
    local var = false
	local hash = 'bot:gmuted:'..chat_id
    local banned = database:sismember(hash, user_id)
	 if banned then
	    var = true
	 end
    return var
end
-----------------------------------------------------------------------------------------------
function get_info(user_id)
  if database:hget('bot:username',user_id) then
    text = '@'..(string.gsub(database:hget('bot:username',user_id), 'false', '') or '')..''
  end
  get_user(user_id)
  return text
  --db:hrem('bot:username',user_id)
end
function get_user(user_id)
  function dl_username(arg, data)
    username = data.username or ''

    --vardump(data)
    database:hset('bot:username',data.id_,data.username_)
  end
  tdcli_function ({
    ID = "GetUser",
    user_id_ = user_id
  }, dl_username, nil)
end
local function getMessage(chat_id, message_id,cb)
  tdcli_function ({
    ID = "GetMessage",
    chat_id_ = chat_id,
    message_id_ = message_id
  }, cb, nil)
end
-----------------------------------------------------------------------------------------------
local function check_filter_words(msg, value)
  local hash = 'bot:filters:'..msg.chat_id_
  if hash then
    local names = database:hkeys(hash)
    local text = ''
    for i=1, #names do
	   if string.match(value:lower(), names[i]:lower()) and not is_mod(msg.sender_user_id_, msg.chat_id_)then
	     local id = msg.id_
         local msgs = {[0] = id}
         local chat = msg.chat_id_
        delete_msg(chat,msgs)
       end
    end
  end
end
-----------------------------------------------------------------------------------------------
function resolve_username(username,cb)
  tdcli_function ({
    ID = "SearchPublicChat",
    username_ = username
  }, cb, nil)
end
  -----------------------------------------------------------------------------------------------
function changeChatMemberStatus(chat_id, user_id, status)
  tdcli_function ({
    ID = "ChangeChatMemberStatus",
    chat_id_ = chat_id,
    user_id_ = user_id,
    status_ = {
      ID = "ChatMemberStatus" .. status
    },
  }, dl_cb, nil)
end
  -----------------------------------------------------------------------------------------------
function getInputFile(file)
  if file:match('/') then
    infile = {ID = "InputFileLocal", path_ = file}
  elseif file:match('^%d+$') then
    infile = {ID = "InputFileId", id_ = file}
  else
    infile = {ID = "InputFilePersistentId", persistent_id_ = file}
  end

  return infile
end
  -----------------------------------------------------------------------------------------------
function del_all_msgs(chat_id, user_id)
  tdcli_function ({
    ID = "DeleteMessagesFromUser",
    chat_id_ = chat_id,
    user_id_ = user_id
  }, dl_cb, nil)
end

  local function deleteMessagesFromUser(chat_id, user_id, cb, cmd)
    tdcli_function ({
      ID = "DeleteMessagesFromUser",
      chat_id_ = chat_id,
      user_id_ = user_id
    },cb or dl_cb, cmd)
  end
  -----------------------------------------------------------------------------------------------
function getChatId(id)
  local chat = {}
  local id = tostring(id)
  
  if id:match('^-100') then
    local channel_id = id:gsub('-100', '')
    chat = {ID = channel_id, type = 'channel'}
  else
    local group_id = id:gsub('-', '')
    chat = {ID = group_id, type = 'group'}
  end
  
  return chat
end
  -----------------------------------------------------------------------------------------------
function chat_leave(chat_id, user_id)
  changeChatMemberStatus(chat_id, user_id, "Left")
end
  -----------------------------------------------------------------------------------------------
function from_username(msg)
   function gfrom_user(extra,result,success)
   if result.username_ then
   F = result.username_
   else
   F = 'nil'
   end
    return F
   end
  local username = getUser(msg.sender_user_id_,gfrom_user)
  return username
end
  -----------------------------------------------------------------------------------------------
function chat_kick(chat_id, user_id)
  changeChatMemberStatus(chat_id, user_id, "Kicked")
end
  -----------------------------------------------------------------------------------------------
function do_notify (user, msg)
  local n = notify.Notification.new(user, msg)
  n:show ()
end
  -----------------------------------------------------------------------------------------------
local function getParseMode(parse_mode)  
  if parse_mode then
    local mode = parse_mode:lower()
  
    if mode == 'markdown' or mode == 'md' then
      P = {ID = "TextParseModeMarkdown"}
    elseif mode == 'html' then
      P = {ID = "TextParseModeHTML"}
    end
  end
  return P
end
  -----------------------------------------------------------------------------------------------
local function getMessage(chat_id, message_id,cb)
  tdcli_function ({
    ID = "GetMessage",
    chat_id_ = chat_id,
    message_id_ = message_id
  }, cb, nil)
end
-----------------------------------------------------------------------------------------------
function sendContact(chat_id, reply_to_message_id, disable_notification, from_background, reply_markup, phone_number, first_name, last_name, user_id)
  tdcli_function ({
    ID = "SendMessage",
    chat_id_ = chat_id,
    reply_to_message_id_ = reply_to_message_id,
    disable_notification_ = disable_notification,
    from_background_ = from_background,
    reply_markup_ = reply_markup,
    input_message_content_ = {
      ID = "InputMessageContact",
      contact_ = {
        ID = "Contact",
        phone_number_ = phone_number,
        first_name_ = first_name,
        last_name_ = last_name,
        user_id_ = user_id
      },
    },
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function sendPhoto(chat_id, reply_to_message_id, disable_notification, from_background, reply_markup, photo, caption)
  tdcli_function ({
    ID = "SendMessage",
    chat_id_ = chat_id,
    reply_to_message_id_ = reply_to_message_id,
    disable_notification_ = disable_notification,
    from_background_ = from_background,
    reply_markup_ = reply_markup,
    input_message_content_ = {
      ID = "InputMessagePhoto",
      photo_ = getInputFile(photo),
      added_sticker_file_ids_ = {},
      width_ = 0,
      height_ = 0,
      caption_ = caption
    },
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function getUserFull(user_id,cb)
  tdcli_function ({
    ID = "GetUserFull",
    user_id_ = user_id
  }, cb, nil)
end
-----------------------------------------------------------------------------------------------
function vardump(value)
  print(serpent.block(value, {comment=false}))
end
-----------------------------------------------------------------------------------------------
function dl_cb(arg, data)
end
-----------------------------------------------------------------------------------------------
local function send(chat_id, reply_to_message_id, disable_notification, text, disable_web_page_preview, parse_mode)
  local TextParseMode = getParseMode(parse_mode)
  
  tdcli_function ({
    ID = "SendMessage",
    chat_id_ = chat_id,
    reply_to_message_id_ = reply_to_message_id,
    disable_notification_ = disable_notification,
    from_background_ = 1,
    reply_markup_ = nil,
    input_message_content_ = {
      ID = "InputMessageText",
      text_ = text,
      disable_web_page_preview_ = disable_web_page_preview,
      clear_draft_ = 0,
      entities_ = {},
      parse_mode_ = TextParseMode,
    },
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function sendaction(chat_id, action, progress)
  tdcli_function ({
    ID = "SendChatAction",
    chat_id_ = chat_id,
    action_ = {
      ID = "SendMessage" .. action .. "Action",
      progress_ = progress or 100
    }
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function changetitle(chat_id, title)
  tdcli_function ({
    ID = "ChangeChatTitle",
    chat_id_ = chat_id,
    title_ = title
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function edit(chat_id, message_id, reply_markup, text, disable_web_page_preview, parse_mode)
  local TextParseMode = getParseMode(parse_mode)
  tdcli_function ({
    ID = "EditMessageText",
    chat_id_ = chat_id,
    message_id_ = message_id,
    reply_markup_ = reply_markup,
    input_message_content_ = {
      ID = "InputMessageText",
      text_ = text,
      disable_web_page_preview_ = disable_web_page_preview,
      clear_draft_ = 0,
      entities_ = {},
      parse_mode_ = TextParseMode,
    },
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function setphoto(chat_id, photo)
  tdcli_function ({
    ID = "ChangeChatPhoto",
    chat_id_ = chat_id,
    photo_ = getInputFile(photo)
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function add_user(chat_id, user_id, forward_limit)
  tdcli_function ({
    ID = "AddChatMember",
    chat_id_ = chat_id,
    user_id_ = user_id,
    forward_limit_ = forward_limit or 50
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function delmsg(arg,data)
  for k,v in pairs(data.messages_) do
    delete_msg(v.chat_id_,{[0] = v.id_})
  end
end
-----------------------------------------------------------------------------------------------
function unpinmsg(channel_id)
  tdcli_function ({
    ID = "UnpinChannelMessage",
    channel_id_ = getChatId(channel_id).ID
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
local function blockUser(user_id)
  tdcli_function ({
    ID = "BlockUser",
    user_id_ = user_id
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
local function unblockUser(user_id)
  tdcli_function ({
    ID = "UnblockUser",
    user_id_ = user_id
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
local function getBlockedUsers(offset, limit)
  tdcli_function ({
    ID = "GetBlockedUsers",
    offset_ = offset,
    limit_ = limit
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function delete_msg(chatid,mid)
  tdcli_function ({
  ID="DeleteMessages", 
  chat_id_=chatid, 
  message_ids_=mid
  },
  dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function chat_del_user(chat_id, user_id)
  changeChatMemberStatus(chat_id, user_id, 'Editor')
end
-----------------------------------------------------------------------------------------------
function getChannelMembers(channel_id, offset, filter, limit)
  if not limit or limit > 200 then
    limit = 200
  end
  tdcli_function ({
    ID = "GetChannelMembers",
    channel_id_ = getChatId(channel_id).ID,
    filter_ = {
      ID = "ChannelMembers" .. filter
    },
    offset_ = offset,
    limit_ = limit
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function getChannelFull(channel_id)
  tdcli_function ({
    ID = "GetChannelFull",
    channel_id_ = getChatId(channel_id).ID
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
local function channel_get_bots(channel,cb)
local function callback_admins(extra,result,success)
    limit = result.member_count_
    getChannelMembers(channel, 0, 'Bots', limit,cb)
    channel_get_bots(channel,get_bots)
end

  getChannelFull(channel,callback_admins)
end
-----------------------------------------------------------------------------------------------
local function getInputMessageContent(file, filetype, caption)
  if file:match('/') then
    infile = {ID = "InputFileLocal", path_ = file}
  elseif file:match('^%d+$') then
    infile = {ID = "InputFileId", id_ = file}
  else
    infile = {ID = "InputFilePersistentId", persistent_id_ = file}
  end

  local inmsg = {}
  local filetype = filetype:lower()

  if filetype == 'animation' then
    inmsg = {ID = "InputMessageAnimation", animation_ = infile, caption_ = caption}
  elseif filetype == 'audio' then
    inmsg = {ID = "InputMessageAudio", audio_ = infile, caption_ = caption}
  elseif filetype == 'document' then
    inmsg = {ID = "InputMessageDocument", document_ = infile, caption_ = caption}
  elseif filetype == 'photo' then
    inmsg = {ID = "InputMessagePhoto", photo_ = infile, caption_ = caption}
  elseif filetype == 'sticker' then
    inmsg = {ID = "InputMessageSticker", sticker_ = infile, caption_ = caption}
  elseif filetype == 'video' then
    inmsg = {ID = "InputMessageVideo", video_ = infile, caption_ = caption}
  elseif filetype == 'voice' then
    inmsg = {ID = "InputMessageVoice", voice_ = infile, caption_ = caption}
  end

  return inmsg
end

-----------------------------------------------------------------------------------------------
function send_file(chat_id, type, file, caption,wtf)
local mame = (wtf or 0)
  tdcli_function ({
    ID = "SendMessage",
    chat_id_ = chat_id,
    reply_to_message_id_ = mame,
    disable_notification_ = 0,
    from_background_ = 1,
    reply_markup_ = nil,
    input_message_content_ = getInputMessageContent(file, type, caption),
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function getUser(user_id, cb)
  tdcli_function ({
    ID = "GetUser",
    user_id_ = user_id
  }, cb, nil)
end
-----------------------------------------------------------------------------------------------
function pin(channel_id, message_id, disable_notification) 
   tdcli_function ({ 
     ID = "PinChannelMessage", 
     channel_id_ = getChatId(channel_id).ID, 
     message_id_ = message_id, 
     disable_notification_ = disable_notification 
   }, dl_cb, nil) 
end 
-----------------------------------------------------------------------------------------------
function tdcli_update_callback(data)
	-------------------------------------------
  if (data.ID == "UpdateNewMessage") then
    local msg = data.message_
    --vardump(data)
    local d = data.disable_notification_
    local chat = chats[msg.chat_id_]
	-------------------------------------------
	if msg.date_ < (os.time() - 30) then
       return false
    end
	-------------------------------------------
	if not database:get("bot:enable:"..msg.chat_id_) and not is_admin(msg.sender_user_id_, msg.chat_id_) then
      return false
    end
    -------------------------------------------
      if msg and msg.send_state_.ID == "MessageIsSuccessfullySent" then
	  --vardump(msg)
	   function get_mymsg_contact(extra, result, success)
             --vardump(result)
       end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,get_mymsg_contact)
         return false 
      end
    -------------* EXPIRE *-----------------
    if not database:get("bot:charge:"..msg.chat_id_) then
     if database:get("bot:enable:"..msg.chat_id_) then
      database:del("bot:enable:"..msg.chat_id_)
      for k,v in pairs(sudo_users) do
        send(v, 0, 1, "link \nLink : "..(database:get("bot:group:link"..msg.chat_id_) or "settings").."\nID : "..msg.chat_id_..'\n\nuse  #leave\n\n/leave'..msg.chat_id_..'\nuse #join:\n/join'..msg.chat_id_..'\n_________________\nuse plan...\n\n<code>30 days:</code>\n/plan1'..msg.chat_id_..'\n\n<code>90 days:</code>\n/plan2'..msg.chat_id_..'\n\n<code>No fanil:</code>\n/plan3'..msg.chat_id_, 1, 'html')
      end
      end
    end
    --------- ANTI FLOOD -------------------
	local hash = 'flood:max:'..msg.chat_id_
    if not database:get(hash) then
        floodMax = 10
    else
        floodMax = tonumber(database:get(hash))
    end

    local hash = 'flood:time:'..msg.chat_id_
    if not database:get(hash) then
        floodTime = 2
    else
        floodTime = tonumber(database:get(hash))
    end
    if not is_mod(msg.sender_user_id_, msg.chat_id_) then
        local hashse = 'anti-flood:'..msg.chat_id_
        if not database:get(hashse) then
                if not is_mod(msg.sender_user_id_, msg.chat_id_) then
                    local hash = 'flood:'..msg.sender_user_id_..':'..msg.chat_id_..':msg-num'
                    local msgs = tonumber(database:get(hash) or 0)
                    if msgs > (floodMax - 1) then
                        local user = msg.sender_user_id_
                        local chat = msg.chat_id_
                        local channel = msg.chat_id_
						 local user_id = msg.sender_user_id_
						 local banned = is_banned(user_id, msg.chat_id_)
                         if banned then
						local id = msg.id_
        				local msgs = {[0] = id}
       					local chat = msg.chat_id_
       						       del_all_msgs(msg.chat_id_, msg.sender_user_id_)
						    else
						 local id = msg.id_
                         local msgs = {[0] = id}
                         local chat = msg.chat_id_
		                chat_kick(msg.chat_id_, msg.sender_user_id_)
						 del_all_msgs(msg.chat_id_, msg.sender_user_id_)
						user_id = msg.sender_user_id_
						local bhash =  'bot:banned:'..msg.chat_id_
                        database:sadd(bhash, user_id)
                           send(msg.chat_id_, msg.id_, 1, '📌¦ _اﻟﻋﺿۆ :_  *('..msg.sender_user_id_..')* \n📌¦ _ممنوع التكرار هنا_\n`��¦ تم طردك !`', 1, 'md')
					  end
                    end
                    database:setex(hash, floodTime, msgs+1)
                end
        end
	end
	
	local hash = 'flood:max:warn'..msg.chat_id_
    if not database:get(hash) then
        floodMax = 10
    else
        floodMax = tonumber(database:get(hash))
    end

    local hash = 'flood:time:'..msg.chat_id_
    if not database:get(hash) then
        floodTime = 2
    else
        floodTime = tonumber(database:get(hash))
    end
    if not is_mod(msg.sender_user_id_, msg.chat_id_) then
        local hashse = 'anti-flood:warn'..msg.chat_id_
        if not database:get(hashse) then
                if not is_mod(msg.sender_user_id_, msg.chat_id_) then
                    local hash = 'flood:'..msg.sender_user_id_..':'..msg.chat_id_..':msg-num'
                    local msgs = tonumber(database:get(hash) or 0)
                    if msgs > (floodMax - 1) then
                        local user = msg.sender_user_id_
                        local chat = msg.chat_id_
                        local channel = msg.chat_id_
						 local user_id = msg.sender_user_id_
						 local banned = is_banned(user_id, msg.chat_id_)
                         if banned then
						local id = msg.id_
        				local msgs = {[0] = id}
       					local chat = msg.chat_id_
       						       del_all_msgs(msg.chat_id_, msg.sender_user_id_)
						    else
						 local id = msg.id_
                         local msgs = {[0] = id}
                         local chat = msg.chat_id_
						 del_all_msgs(msg.chat_id_, msg.sender_user_id_)
						user_id = msg.sender_user_id_
						local bhash =  'bot:muted:'..msg.chat_id_
                        database:sadd(bhash, user_id)
                           send(msg.chat_id_, msg.id_, 1, '📌¦ _اﻟﻋﺿۆ :_  *('..msg.sender_user_id_..')* \n📌¦ _ممنوع التكرار هنا_\n`📌¦ تم كتمك !`', 1, 'md')

					  end
                    end
                    database:setex(hash, floodTime, msgs+1)
                end
        end
	end
	-------------------------------------------
	database:incr("bot:allmsgs")
	if msg.chat_id_ then
      local id = tostring(msg.chat_id_)
      if id:match('-100(%d+)') then
        if not database:sismember("bot:groups",msg.chat_id_) then
            database:sadd("bot:groups",msg.chat_id_)
        end
        elseif id:match('^(%d+)') then
        if not database:sismember("bot:userss",msg.chat_id_) then
            database:sadd("bot:userss",msg.chat_id_)
        end
        else
        if not database:sismember("bot:groups",msg.chat_id_) then
            database:sadd("bot:groups",msg.chat_id_)
        end
     end
    end
	-------------------------------------------
    -------------* MSG TYPES *-----------------
   if msg.content_ then
   	if msg.reply_markup_ and  msg.reply_markup_.ID == "ReplyMarkupInlineKeyboard" then
		print("Send INLINE KEYBOARD")
	msg_type = 'MSG:Inline'
	-------------------------
    elseif msg.content_.ID == "MessageText" then
	text = msg.content_.text_
		print("SEND TEXT")
	msg_type = 'MSG:Text'
	-------------------------
	elseif msg.content_.ID == "MessagePhoto" then
	print("SEND PHOTO")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Photo'
	-------------------------
	elseif msg.content_.ID == "MessageChatAddMembers" then
	print("NEW ADD TO GROUP")
	msg_type = 'MSG:NewUserAdd'
	-------------------------
	elseif msg.content_.ID == "MessageChatJoinByLink" then
		print("JOIN TO GROUP")
	msg_type = 'MSG:NewUserLink'
	-------------------------
	elseif msg.content_.ID == "MessageSticker" then
		print("SEND STICKER")
	msg_type = 'MSG:Sticker'
	-------------------------
	elseif msg.content_.ID == "MessageAudio" then
		print("SEND MUSIC")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Audio'
	-------------------------
	elseif msg.content_.ID == "MessageVoice" then
		print("SEND VOICE")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Voice'
	-------------------------
	elseif msg.content_.ID == "MessageVideo" then
		print("SEND VIDEO")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Video'
	-------------------------
	elseif msg.content_.ID == "MessageAnimation" then
		print("SEND GIF")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Gif'
	-------------------------
	elseif msg.content_.ID == "MessageLocation" then
		print("SEND LOCATION")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Location'
	-------------------------
	elseif msg.content_.ID == "MessageChatJoinByLink" or msg.content_.ID == "MessageChatAddMembers" then
	msg_type = 'MSG:NewUser'
	-------------------------
	elseif msg.content_.ID == "MessageContact" then
		print("SEND CONTACT")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Contact'
	-------------------------
	end
   end
    -------------------------------------------
    -------------------------------------------
    if ((not d) and chat) then
      if msg.content_.ID == "MessageText" then
        do_notify (chat.title_, msg.content_.text_)
      else
        do_notify (chat.title_, msg.content_.ID)
      end
    end
  -----------------------------------------------------------------------------------------------
                                     -- end functions --
  -----------------------------------------------------------------------------------------------
  -----------------------------------------------------------------------------------------------
  -----------------------------------------------------------------------------------------------
  -----------------------------------------------------------------------------------------------
                                     -- start code --
  -----------------------------------------------------------------------------------------------
  -------------------------------------- Process mod --------------------------------------------
  -----------------------------------------------------------------------------------------------
  
  -------------------------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------------
  --------------------------******** START MSG CHECKS ********-------------------------------------------
  -------------------------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------------
if is_banned(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
		  chat_kick(msg.chat_id_, msg.sender_user_id_)
		  return 
end

if is_gbanned(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
		  chat_kick(msg.chat_id_, msg.sender_user_id_)
		  return 
end

if is_muted(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        local user_id = msg.sender_user_id_
          delete_msg(chat,msgs)
		  return 
end
if database:get('bot:muteall'..msg.chat_id_) and not is_mod(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
        return 
end

if database:get('bot:muteallwarn'..msg.chat_id_) and not is_mod(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الوسائط</code>", 1, 'html')
        return 
end

if database:get('bot:muteallban'..msg.chat_id_) and not is_mod(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الوسائط\n📌¦ تم طردك !</code>", 1, 'html')
        return 
end
    database:incr('user:msgs'..msg.chat_id_..':'..msg.sender_user_id_)
	database:incr('group:msgs'..msg.chat_id_)
if msg.content_.ID == "MessagePinMessage" then
  if database:get('pinnedmsg'..msg.chat_id_) and database:get('bot:pin:mute'..msg.chat_id_) then
   unpinmsg(msg.chat_id_)
   local pin_id = database:get('pinnedmsg'..msg.chat_id_)
         pin(msg.chat_id_,pin_id,0)
   end
end
    database:incr('user:msgs'..msg.chat_id_..':'..msg.sender_user_id_)
	database:incr('group:msgs'..msg.chat_id_)
if msg.content_.ID == "MessagePinMessage" then
  if database:get('pinnedmsg'..msg.chat_id_) and database:get('bot:pin:warn'..msg.chat_id_) then
   send(msg.chat_id_, msg.id_, 1, "*> Your ID :* _"..msg.sender_user_id_.."_\n*> UserName :* "..get_info(msg.sender_user_id_).."\n*> Pin is Locked Group*", 1, 'md')
   unpinmsg(msg.chat_id_)
   local pin_id = database:get('pinnedmsg'..msg.chat_id_)
         pin(msg.chat_id_,pin_id,0)
   end
end
if database:get('bot:viewget'..msg.sender_user_id_) then 
    if not msg.forward_info_ then
		send(msg.chat_id_, msg.id_, 1, '`📌¦` _قم بعمل توجيه للمنشور_', 1, 'md')
		database:del('bot:viewget'..msg.sender_user_id_)
	else
		send(msg.chat_id_, msg.id_, 1, '`📌¦` _عدد المشاهدات_ :\n`📌¦` '..msg.views_..' _مشاهده_', 1, 'md')
        database:del('bot:viewget'..msg.sender_user_id_)
	end
end
if msg_type == 'MSG:Photo' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
     if database:get('bot:photo:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
        if database:get('bot:photo:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
		   chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الصور\n📌¦ تم طردك !</code>", 1, 'html')

          return 
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:photo:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الصور</code>", 1, 'html')
 
          return 
   end
   end
  elseif msg_type == 'MSG:Inline' then
   if not is_mod(msg.sender_user_id_, msg.chat_id_) then
    if database:get('bot:inline:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:inline:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الانلاين\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:inline:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الانلاين</code>", 1, 'html')
          return 
   end
   end
  elseif msg_type == 'MSG:Sticker' then
   if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:sticker:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:sticker:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الملصقات\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:sticker:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الملصقات</code>", 1, 'html')
          return 
   end
   end
elseif msg_type == 'MSG:NewUserLink' then
  if database:get('bot:tgservice:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
   function get_welcome(extra,result,success)
    if database:get('welcome:'..msg.chat_id_) then
        text = database:get('welcome:'..msg.chat_id_)
    else
        text = 'Hi {firstname} 😃'
    end
    local text = text:gsub('{firstname}',(result.first_name_ or ''))
    local text = text:gsub('{lastname}',(result.last_name_ or ''))
    local text = text:gsub('{username}',(result.username_ or ''))
         send(msg.chat_id_, msg.id_, 1, text, 1, 'html')
   end
	  if database:get("bot:welcome"..msg.chat_id_) then
        getUser(msg.sender_user_id_,get_welcome)
      end
elseif msg_type == 'MSG:NewUserAdd' then
  if database:get('bot:tgservice:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
      --vardump(msg)
   if msg.content_.members_[0].username_ and msg.content_.members_[0].username_:match("[Bb][Oo][Tt]$") then
      if database:get('bot:bots:mute'..msg.chat_id_) and not is_mod(msg.content_.members_[0].id_, msg.chat_id_) then
		 chat_kick(msg.chat_id_, msg.content_.members_[0].id_)
		 return false
	  end
   end
   if is_banned(msg.content_.members_[0].id_, msg.chat_id_) then
		 chat_kick(msg.chat_id_, msg.content_.members_[0].id_)
		 return false
   end
   if database:get("bot:welcome"..msg.chat_id_) then
    if database:get('welcome:'..msg.chat_id_) then
        text = database:get('welcome:'..msg.chat_id_)
    else
        text = 'Hi {firstname} 😃'
    end
    local text = text:gsub('{firstname}',(msg.content_.members_[0].first_name_ or ''))
    local text = text:gsub('{lastname}',(msg.content_.members_[0].last_name_ or ''))
    local text = text:gsub('{username}',('@'..msg.content_.members_[0].username_ or ''))
         send(msg.chat_id_, msg.id_, 1, text, 1, 'html')
   end
elseif msg_type == 'MSG:Contact' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:contact:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:contact:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال جهات الاتصال\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:contact:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال جهات الاتصال</code>", 1, 'html')
          return 
   end
   end
elseif msg_type == 'MSG:Audio' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:music:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:music:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الاغاني\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:music:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الاغاني</code>", 1, 'html')
          return 
   end
   end
elseif msg_type == 'MSG:Voice' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:voice:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return  
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:voice:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الصوتيات\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:voice:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الصوتيات</code>", 1, 'html')
          return 
   end
   end
elseif msg_type == 'MSG:Location' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:location:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return  
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:location:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الشبكات\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:location:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الشبكات</code>", 1, 'html')
          return 
   end
   end
elseif msg_type == 'MSG:Video' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:video:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return  
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:video:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الفيديو\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:video:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الفيديو</code>", 1, 'html')
          return 
   end
   end
elseif msg_type == 'MSG:Gif' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:gifs:mute'..msg.chat_id_) and not is_mod(msg.sender_user_id_, msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return  
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:gifs:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الصور المتحركه\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:gifs:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الصور المتحركه</code>", 1, 'html')
          return 
   end
   end
elseif msg_type == 'MSG:Text' then
 --vardump(msg)
    if database:get("bot:group:link"..msg.chat_id_) == 'Waiting For Link!\nPls Send Group Link' and is_mod(msg.sender_user_id_, msg.chat_id_) then if text:match("(https://telegram.me/joinchat/%S+)") or text:match("(https://t.me/joinchat/%S+)") then 	 local glink = text:match("(https://telegram.me/joinchat/%S+)") or text:match("(https://t.me/joinchat/%S+)") local hash = "bot:group:link"..msg.chat_id_ database:set(hash,glink) 			 send(msg.chat_id_, msg.id_, 1, '*New link Set!*', 1, 'md') send(msg.chat_id_, 0, 1, '<b>New Group link:</b>\n'..glink, 1, 'html')
      end
   end
    function check_username(extra,result,success)
	 --vardump(result)
	local username = (result.username_ or '')
	local svuser = 'user:'..result.id_
	if username then
      database:hset(svuser, 'username', username)
    end
	if username and username:match("[Bb][Oo][Tt]$") then
      if database:get('bot:bots:mute'..msg.chat_id_) and not is_mod(result.id_, msg.chat_id_) then
		 chat_kick(msg.chat_id_, result.id_)
		 return false
		 end
	  end
   end
    getUser(msg.sender_user_id_,check_username)
   database:set('bot:editid'.. msg.id_,msg.content_.text_)
   if not is_mod(msg.sender_user_id_, msg.chat_id_) then
    check_filter_words(msg, text)
	if text:match("[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm].[Mm][Ee]") or 
text:match("[Tt].[Mm][Ee]") or
text:match("[Tt][Ll][Gg][Rr][Mm].[Mm][Ee]") then
     if database:get('bot:links:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
       if database:get('bot:links:ban'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        local user_id = msg.sender_user_id_
        delete_msg(chat,msgs)
chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الروابط\n📌¦ تم طردك !</code>", 1, 'html')
  end
       if database:get('bot:links:warn'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        local user_id = msg.sender_user_id_
        delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الروابط</code>", 1, 'html')
	end
 end

            if text then
              local _nl, ctrl_chars = string.gsub(text, '%c', '')
              local _nl, real_digits = string.gsub(text, '%d', '')
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              local hash = 'bot:sens:spam'..msg.chat_id_
              if not database:get(hash) then
                sens = 100
              else
                sens = tonumber(database:get(hash))
              end
              if database:get('bot:spam:mute'..msg.chat_id_) and string.len(text) > (sens) or ctrl_chars > (sens) or real_digits > (sens) then
                delete_msg(chat,msgs)
              end
          end 
          
            if text then
              local _nl, ctrl_chars = string.gsub(text, '%c', '')
              local _nl, real_digits = string.gsub(text, '%d', '')
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              local hash = 'bot:sens:spam:warn'..msg.chat_id_
              if not database:get(hash) then
                sens = 100
              else
                sens = tonumber(database:get(hash))
              end
              if database:get('bot:spam:warn'..msg.chat_id_) and string.len(text) > (sens) or ctrl_chars > (sens) or real_digits > (sens) then
                delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الكلايش</code>", 1, 'html')
              end
          end 

	if text then
     if database:get('bot:text:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:text:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الدردشه\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:text:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الدردشه</code>", 1, 'html')
          return 
   end
if msg.forward_info_ then
if database:get('bot:forward:mute'..msg.chat_id_) then
	if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
   end
end
end
if msg.forward_info_ then
if database:get('bot:forward:ban'..msg.chat_id_) then
	if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        local user_id = msg.sender_user_id_
        delete_msg(chat,msgs)
		                chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع عمل توجيه\n📌¦ تم طردك !</code>", 1, 'html')
	end
   end

if msg.forward_info_ then
if database:get('bot:forward:warn'..msg.chat_id_) then
	if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        local user_id = msg.sender_user_id_
        delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع عمل توجيه</code>", 1, 'html')
	end
   end
end
elseif msg_type == 'MSG:Text' then
   if text:match("@") or msg.content_.entities_[0] and msg.content_.entities_[0].ID == "MessageEntityMentionName" then
   if database:get('bot:tag:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:tag:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال المعرفات\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:tag:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال المعرفات</code>", 1, 'html')
          return 
   end
 end
   	if text:match("#") then
      if database:get('bot:hashtag:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:hashtag:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال التاكات\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:hashtag:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال التاكات</code>", 1, 'html')
          return 
   end
end

   	if text:match("/") then
      if database:get('bot:cmd:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end 
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
      if database:get('bot:cmd:ban'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        local user_id = msg.sender_user_id_
        delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الشارحه\n📌¦ تم طردك !</code>", 1, 'html')
	end 
	      if database:get('bot:cmd:warn'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        local user_id = msg.sender_user_id_
        delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الشارحه</code>", 1, 'html')
	end 
	end
   	if text:match("[Hh][Tt][Tt][Pp][Ss]://") or text:match("[Hh][Tt][Tt][Pp]://") or text:match(".[Ii][Rr]") or text:match(".[Cc][Oo][Mm]") or text:match(".[Oo][Rr][Gg]") or text:match(".[Ii][Nn][Ff][Oo]") or text:match("[Ww][Ww][Ww].") or text:match(".[Tt][Kk]") then
      if database:get('bot:webpage:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:webpage:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال المواقع\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:webpage:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال المواقع</code>", 1, 'html')
          return 
   end
 end
   	if text:match("[\216-\219][\128-\191]") then
      if database:get('bot:arabic:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:arabic:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال العربيه\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:arabic:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال العربيه</code>", 1, 'html')
          return 
   end
 end
   	  if text:match("[ASDFGHJKLQWERTYUIOPZXCVBNMasdfghjklqwertyuiopzxcvbnm]") then
      if database:get('bot:english:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	  end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
	          if database:get('bot:english:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الانكليزيه\n📌¦ تم طردك !</code>", 1, 'html')
          return 
   end
   
        if database:get('bot:english:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "<code>📌¦ ٱﯾدﯾك :</code><i>"..msg.sender_user_id_.."</i>\n<code>📌¦ ممنوع ارسال الانكليزيه</code>", 1, 'html')
          return 
   end
     end
    end
   end
  -------------------------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------------
  ---------------------------******** END MSG CHECKS ********--------------------------------------------
  -------------------------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------------
  if database:get('bot:cmds'..msg.chat_id_) and not is_mod(msg.sender_user_id_, msg.chat_id_) then
  return 
  else
    ------------------------------------ With Pattern -------------------------------------------
	if text:match("^ping$") then
	   send(msg.chat_id_, msg.id_, 1, '_Pong_', 1, 'md')
	end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ll][Ee][Aa][Vv][Ee]") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	     chat_leave(msg.chat_id_, bot_id)
    end
    
	if text:match("^مغادره") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	     chat_leave(msg.chat_id_, bot_id)
    end
	-----------------------------------------------------------------------------------------------
        local text = msg.content_.text_:gsub('رفع ادمن','setmote')
	if text:match("^[Ss][Ee][Tt][Mm][Oo][Tt][Ee]$")  and is_owner(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function promote_by_reply(extra, result, success)
	local hash = 'bot:mods:'..msg.chat_id_
	if database:sismember(hash, result.sender_user_id_) then
              if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is Already moderator._', 1, 'md')
              else
         send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _بالفعل ادمن_', 1, 'md')
              end
            else
         database:sadd(hash, result.sender_user_id_)
              if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _promoted as moderator._', 1, 'md')
              else
         send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _تم رفعه ادمن_', 1, 'md')
              end
	end 
    end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,promote_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ee][Tt][Mm][Oo][Tt][Ee] @(.*)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Ss][Ee][Tt][Mm][Oo][Tt][Ee]) @(.*)$")} 
	function promote_by_username(extra, result, success)
	if result.id_ then
	        database:sadd('bot:mods:'..msg.chat_id_, result.id_)
              if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<code>User '..result.id_..' promoted as moderator.!</code>'
          else
            texts = '`📌¦` _اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦ ` _تم رفعه ادمن_'
            end
          else 
              if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<code>User not found!</code>'
          else
            texts = '`📌¦ `_ خطأ !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],promote_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ee][Tt][Mm][Oo][Tt][Ee] (%d+)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Ss][Ee][Tt][Mm][Oo][Tt][Ee]) (%d+)$")} 	
	        database:sadd('bot:mods:'..msg.chat_id_, ap[2])
          if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..ap[2]..'* _promoted as moderator._', 1, 'md')
          else
	send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..ap[2]..'*\n`📌¦` _تم رفعه ادمن_', 1, 'md')
          end
    end
	-----------------------------------------------------------------------------------------------
        local text = msg.content_.text_:gsub('تنزيل ادمن','remmote')
	if text:match("^[Rr][Ee][Mm][Mm][Oo][Tt][Ee]$") and is_owner(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function demote_by_reply(extra, result, success)
	local hash = 'bot:mods:'..msg.chat_id_
	if not database:sismember(hash, result.sender_user_id_) then
              if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is not Promoted._', 1, 'md')
              else
         send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _بالفعل تم تنزيله من الادمنيه_', 1, 'md')
              end
	else
         database:srem(hash, result.sender_user_id_)
              if database:get('lang:gp:'..msg.chat_id_) then

         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _Demoted._', 1, 'md')
else
         send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _تم تنزيله من الادمنيه_', 1, 'md')
	end
  end
  end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,demote_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Rr][Ee][Mm][Mm][Oo][Tt][Ee] @(.*)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
	local hash = 'bot:mods:'..msg.chat_id_
	local ap = {string.match(text, "^([Rr][Ee][Mm][Mm][Oo][Tt][Ee]) @(.*)$")} 
	function demote_by_username(extra, result, success)
	if result.id_ then
         database:srem(hash, result.id_)
              if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<b>User </b><code>'..result.id_..'</code> <b>Demoted</b>'
          else 
            texts = '`📌¦` _اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦` _تم تنزيله من الادمنيه_'
    end
          else 
              if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<code>User not found!</code>'
          else
            texts = '`📌¦ `_ خطأ !_'
        end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],demote_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Rr][Ee][Mm][Mm][Oo][Tt][Ee] (%d+)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
	local hash = 'bot:mods:'..msg.chat_id_
	local ap = {string.match(text, "^([Rr][Ee][Mm][Mm][Oo][Tt][Ee]) (%d+)$")} 	
         database:srem(hash, ap[2])
              if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..ap[2]..'* _Demoted._', 1, 'md')
else 
	send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..ap[2]..'*\n`📌¦` _تم تنزيله من الادمنيه_', 1, 'md')
  end
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('حظر','Ban')
	if text:match("^[Bb][Aa][Nn]$") and is_mod(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function ban_by_reply(extra, result, success)
	local hash = 'bot:banned:'..msg.chat_id_
	if is_mod(result.sender_user_id_, result.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick/Ban] Moderators!!*', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`📌¦` _لا تستطيع حظر الادمنيه_', 1, 'md')
end
    else
    if database:sismember(hash, result.sender_user_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is Already Banned._', 1, 'md')
else
           send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _بالفعل تم حظره_', 1, 'md')
end
		 chat_kick(result.chat_id_, result.sender_user_id_)
	else
         database:sadd(hash, result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _Banned._', 1, 'md')
       else
                  send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _تم حظره_', 1, 'md')
end
		 chat_kick(result.chat_id_, result.sender_user_id_)
	end
    end
	end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,ban_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Bb][Aa][Nn] @(.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Bb][Aa][Nn]) @(.*)$")} 
	function ban_by_username(extra, result, success)
	if result.id_ then
	if is_mod(result.id_, msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick/Ban] Moderators!!*', 1, 'md')
       else
                  send(msg.chat_id_, msg.id_, 1, '`📌¦` _لا تستطيع حظر الادمنيه_', 1, 'md')
end
    else
	        database:sadd('bot:banned:'..msg.chat_id_, result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<b>User </b><code>'..result.id_..'</code> <b>Banned.!</b>'
else
              texts = '`📌¦` _اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦ ` _تم حظره_'
end
		 chat_kick(msg.chat_id_, result.id_)
	end
          else 
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<code>User not found!</code>'
          else
                        texts = '`📌¦ `_ خطأ !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],ban_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Bb][Aa][Nn] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Bb][Aa][Nn]) (%d+)$")}
	if is_mod(ap[2], msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick/Ban] Moderators!!*', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`📌¦` _لا تستطيع حظر الادمنيه_', 1, 'md')
end
    else
	        database:sadd('bot:banned:'..msg.chat_id_, ap[2])
		 chat_kick(msg.chat_id_, ap[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..ap[2]..'* _Banned._', 1, 'md')
else
  	send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..ap[2]..'*\n`📌¦` _تم حظره_', 1, 'md')
  	end
	end
end
  ----------------------------------------------unban--------------------------------------------
          local text = msg.content_.text_:gsub('الغاء حظر','unban')
  	if text:match("^[Uu][Nn][Bb][Aa][Nn]$") and is_mod(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function unban_by_reply(extra, result, success)
	local hash = 'bot:banned:'..msg.chat_id_
	if not database:sismember(hash, result.sender_user_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is not Banned._', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _لم يتم حظره_', 1, 'md')
end
	else
         database:srem(hash, result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _Unbanned._', 1, 'md')
       else
                  send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _تم الغاء حظره_', 1, 'md')
end
	end
    end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,unban_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Uu][Nn][Bb][Aa][Nn] @(.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Uu][Nn][Bb][Aa][Nn]) @(.*)$")} 
	function unban_by_username(extra, result, success)
	if result.id_ then
         database:srem('bot:banned:'..msg.chat_id_, result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
            text = '<b>User </b><code>'..result.id_..'</code> <b>Unbanned.!</b>'
      else
                    texts = '`📌¦` _اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦` _تم الغاء حظره_'
end
          else 
                  if database:get('lang:gp:'..msg.chat_id_) then
            text = '<code>User not found!</code>'
          else
                        texts = '`📌¦ `_ خطأ !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
    end
	      resolve_username(ap[2],unban_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Uu][Nn][Bb][Aa][Nn] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Uu][Nn][Bb][Aa][Nn]) (%d+)$")} 	
	        database:srem('bot:banned:'..msg.chat_id_, ap[2])
        if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..ap[2]..'* _Unbanned._', 1, 'md')
else
  send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..ap[2]..'*\n`📌¦` _تم الغاء حظره_', 1, 'md')
end
  end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('حذف الكل','delall')
	if text:match("^[Dd][Ee][Ll][Aa][Ll][Ll]$") and is_owner(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function delall_by_reply(extra, result, success)
	if is_mod(result.sender_user_id_, result.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t Delete Msgs from Moderators!!*', 1, 'md')
else
           send(msg.chat_id_, msg.id_, 1, '`📌¦` _لا تستطيع حذف رسائل الادمنيه_', 1, 'md')
end
else
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_All Msgs from _ *'..result.sender_user_id_..'* _Has been deleted!!_', 1, 'md')
       else
                  send(msg.chat_id_, msg.id_, 1, '`📌¦` _ كل رسائل اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _تم مسحها_', 1, 'md')
end
		     del_all_msgs(result.chat_id_, result.sender_user_id_)
    end
	end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,delall_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Dd][Ee][Ll][Aa][Ll][Ll] (%d+)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
		local ass = {string.match(text, "^([Dd][Ee][Ll][Aa][Ll][Ll]) (%d+)$")} 
	if is_mod(ass[2], msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t Delete Msgs from Moderators!!*', 1, 'md')
else
           sesend(msg.chat_id_, msg.id_, 1, '`📌¦` _لا تستطيع حذف رسائل الادمنيه_', 1, 'md')
end
else
	 		     del_all_msgs(msg.chat_id_, ass[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_All Msgs from _ *'..ass[2]..'* _Has been deleted!!_', 1, 'md')
       else
                  send(msg.chat_id_, msg.id_, 1, '`📌¦` _ كل رسائل اﻟﻋﺿۆ_ : *'..ap[2]..'*\n`📌¦` _تم مسحها_', 1, 'md')
end    end
	end
 -----------------------------------------------------------------------------------------------
	if text:match("^[Dd][Ee][Ll][Aa][Ll][Ll] @(.*)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Dd][Ee][Ll][Aa][Ll][Ll]) @(.*)$")} 
	function delall_by_username(extra, result, success)
	if result.id_ then
	if is_mod(result.id_, msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t Delete Msgs from Moderators!!*', 1, 'md')
else
           send(msg.chat_id_, msg.id_, 1, '`📌¦` _لا تستطيع حذف رسائل الادمنيه_', 1, 'md')
end
return false
    end
		 		     del_all_msgs(msg.chat_id_, result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
            text = '<b>All Msg From user</b> <code>'..result.id_..'</code> <b>Deleted!</b>'
          else 
                        text = '`📌¦` _ كل رسائل اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦` _تم مسحها_'
end
          else 
                  if database:get('lang:gp:'..msg.chat_id_) then
            text = '<code>User not found!</code>'
          else
                        text = '`📌¦ `_ خطأ !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
    end
	      resolve_username(ap[2],delall_by_username)
    end
  -----------------------------------------banall--------------------------------------------------
          local text = msg.content_.text_:gsub('حظر عام','banall')
          if text:match("^[Bb][Aa][Nn][Aa][Ll][Ll] @(.*)$") and is_sudo(msg) then
            local ap = {string.match(text, "^([Bb][Aa][Nn][Aa][Ll][Ll]) @(.*)$")}
            function banall_by_username(extra, result, success)
	if result.id_ then
    if database:sismember('bot:gbanned:', result.id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.id_..'* _is Already Banned all._', 1, 'md')
       else
                  send(msg.chat_id_, msg.id_, 1, '`📌¦`_اﻟﻋﺿۆ_ : *'..result.id_..'*\n`📌¦` _بالفعل تم حظره عام_', 1, 'md')
end
                                   chat_kick(msg.chat_id_, result.id_)
	else
         database:sadd('bot:gbanned:', result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.id_..'* _Banall Groups_', 1, 'md')
       else
                  send(msg.chat_id_, msg.id_, 1, '`📌¦`_اﻟﻋﺿۆ_ : *'..result.id_..'*\n`📌¦` _تم حظره عام_', 1, 'md')
end
                                   chat_kick(msg.chat_id_, result.id_)
                                   end
                else
                  if database:get('lang:gp:'..msg.chat_id_) then
                  texts = '<code>User not found!</code>'
                else 
                                    texts = '`📌¦ `_ خطأ !_'
end
end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
end
            resolve_username(ap[2],banall_by_username)
          end

          if text:match("^[Bb][Aa][Nn][Aa][Ll][Ll] (%d+)$") and is_sudo(msg) then
            local ap = {string.match(text, "^([Bb][Aa][Nn][Aa][Ll][Ll]) (%d+)$")}
            if not database:sismember("botadmins:", ap[2]) or sudo_users == result.sender_user_id_ then
	         	database:sadd('bot:gbanned:', ap[2])
              chat_kick(msg.chat_id_, ap[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
                text = '<b>User :</b> <code>'..ap[2]..'</code> <b> Has been Globally Banned !</b>'
              else 
                                text = '`📌¦`_اﻟﻋﺿۆ_ : *'..ap[2]..'*\n`📌¦` _تم حظره عام_'
end
          else
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '<b>User not found!</b>'
                else
                  text = '`📌¦ `_ خطأ !_'
end
end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
            end

          if text:match("^[Bb][Aa][Nn][Aa][Ll][Ll]$") and is_sudo(msg) then
            function banall_by_reply(extra, result, success)
                database:sadd('bot:gbanned:', result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '<b>User :</b> '..get_info(result.sender_user_id_)..' <b>Has been Globally Banned !</b>'
                else
                    text = '`📌¦` _اﻟﻋﺿۆ_ : '..get_info(result.sender_user_id_)..'\n`📌¦` _تم حظره عام_'
end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
                chat_kick(result.chat_id_, result.id_)
              end
            tdcli.getMessage(msg.chat_id_, msg.reply_to_message_id_,banall_by_reply)
          end
  -----------------------------------------unbanall------------------------------------------------
          local text = msg.content_.text_:gsub('الغاء العام','unbanall')
          if text:match("^[Uu][Nn][Bb][Aa][Nn][Aa][Ll][Ll] @(.*)$") and is_sudo(msg) then
            local ap = {string.match(text, "^([Uu][Nn][Bb][Aa][Nn][Aa][Ll][Ll]) @(.*)$")}
            function unbanall_by_username(extra, result, success)
              if result.id_ then
                database:srem('bot:gbanned:', result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '<b>User</b> '..get_info(result.id_)..' <b>Has been Globally Unbanned !</b>'
                else 
                  text = '`📌¦` _اﻟﻋﺿۆ_ : '..get_info(result.id_)..'\n`📌¦` _تم الغاء حظره من العام_'
end
              else
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '<b>User not found!</b>'
                else 
                 text = '`📌¦ `_ خطأ !_'
end
              end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
            end
            resolve_username(ap[2],unbanall_by_username)
          end

          if text:match("^[Uu][Nn][Bb][Aa][Nn][Aa][Ll][Ll] (%d+)$") and is_sudo(msg) then
            local ap = {string.match(text, "^([Uu][Nn][Bb][Aa][Nn][Aa][Ll][Ll]) (%d+)$")}
            if ap[2] then
                database:srem('bot:gbanned:', ap[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
              text = '<b>User :</b> '..(ap[2])..' <b>Has been Globally Unbanned !</b>'
            else 
              text = '`📌¦` _اﻟﻋﺿۆ_ : '..p[2]..'\n`📌¦` _تم الغاء حظره من العام_'
end
            else
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '<b>User not found!</b>'
                else 
                  text = '`📌¦ `_ خطأ !_'
end
              end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
          end

          if text:match("^[Uu][Nn][Bb][Aa][Nn][Aa][Ll][Ll]$") and is_sudo(msg) and msg.reply_to_message_id_ then
            function unbanall_by_reply(extra, result, success)
              if not database:sismember('bot:gbanned:', result.sender_user_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '<b>User :</b> '..get_info(result.sender_user_id_)..' <b>is Not Globally Banned !</b>'
                else
                  text = '`📌¦` _اﻟﻋﺿۆ_ : '..get_info(result.sender_user_id_)..'\n`📌¦` _لم يتم حظره عام_'
              end
                  else
             database:srem('bot:gbanned:', result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '<b>User :</b> '..get_info(result.sender_user_id_)..' <b>Has been Globally Unbanned !</b>'
             else
                  text = '`📌¦` _اﻟﻋﺿۆ_ : '..get_info(result.sender_user_id_)..'\n`📌¦` _تم الغاء حظره من العام_'
            end
                  end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
              end
            getMessage(msg.chat_id_, msg.reply_to_message_id_,unbanall_by_reply)
          end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('كتم','silent')
	if text:match("^[Ss][Ii][Ll][Ee][Nn][Tt]$") and is_mod(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function mute_by_reply(extra, result, success)
	local hash = 'bot:muted:'..msg.chat_id_
	if is_mod(result.sender_user_id_, result.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick/Ban] Moderators!!*', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`📌¦` _لا تستطيع كتم الادمنيه_', 1, 'md')
end
    else
    if database:sismember(hash, result.sender_user_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is Already silent._', 1, 'md')
else 
           send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _بالفعل تم كتمه_', 1, 'md')
end
	else
         database:sadd(hash, result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _silent_', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _تم كتمه_', 1, 'md')
end
	end
    end
	end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,mute_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ii][Ll][Ee][Nn][Tt] @(.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Ss][Ii][Ll][Ee][Nn][Tt]) @(.*)$")} 
	function mute_by_username(extra, result, success)
	if result.id_ then
	if is_mod(result.id_, msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick/Ban] Moderators!!*', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`📌¦` _لا تستطيع كتم الادمنيه_', 1, 'md')
end
    else
	        database:sadd('bot:muted:'..msg.chat_id_, result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<b>User </b><code>'..result.id_..'</code> <b>silent</b>'
          else 
            texts = '`📌¦` _اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦` _تم كتمه_'
end
		 chat_kick(msg.chat_id_, result.id_)
	end
          else 
              if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<code>User not found!</code>'
          else 
                        texts = '`📌¦ `_ خطأ !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],mute_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ii][Ll][Ee][Nn][Tt] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Ss][Ii][Ll][Ee][Nn][Tt]) (%d+)$")}
	if is_mod(ap[2], msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick/Ban] Moderators!!*', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`📌¦` _لا تستطيع كتم الادمنيه_', 1, 'md')
end
    else
	        database:sadd('bot:muted:'..msg.chat_id_, ap[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..ap[2]..'* _silent_', 1, 'md')
else 
  	send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..ap[2]..'*\n`📌¦` _تم كتمه_', 1, 'md')
end
	end
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('الغاء كتم','unsilent')
	if text:match("^[Uu][Nn][Ss][Ii][Ll][Ee][Nn][Tt]$") and is_mod(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function unmute_by_reply(extra, result, success)
	local hash = 'bot:muted:'..msg.chat_id_
	if not database:sismember(hash, result.sender_user_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is not silent._', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _بالفعل تم الغاء كتمه_', 1, 'md')
end
	else
         database:srem(hash, result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _unsilent_', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _تم الغاء كتمه_', 1, 'md')
end
	end
    end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,unmute_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Uu][Nn][Ss][Ii][Ll][Ee][Nn][Tt] @(.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Uu][Nn][Ss][Ii][Ll][Ee][Nn][Tt]) @(.*)$")} 
	function unmute_by_username(extra, result, success)
	if result.id_ then
         database:srem('bot:muted:'..msg.chat_id_, result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
            text = '<b>User </b><code>'..result.id_..'</code> <b>unsilent.!</b>'
          else 
                        text = '`📌¦` _اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦ ` _تم الغاء كتمه_'
end
          else 
                  if database:get('lang:gp:'..msg.chat_id_) then
            text = '<code>User not found!</code>'
          else 
                        text = '`📌¦ `_ خطأ !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
    end
	      resolve_username(ap[2],unmute_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Uu][Nn][Ss][Ii][Ll][Ee][Nn][Tt] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Uu][Nn][Ss][Ii][Ll][Ee][Nn][Tt]) (%d+)$")} 	
	        database:srem('bot:muted:'..msg.chat_id_, ap[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..ap[2]..'* _unsilent_', 1, 'md')
else 
  	send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..ap[2]..'*\n`📌¦` _تم الغاء كتمه_', 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('رفع مدير','setowner')
	if text:match("^[Ss][Ee][Tt][Oo][Ww][Nn][Ee][Rr]$") and is_admin(msg.sender_user_id_) and msg.reply_to_message_id_ then
	function setowner_by_reply(extra, result, success)
	local hash = 'bot:owners:'..msg.chat_id_
	if database:sismember(hash, result.sender_user_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is Already Owner._', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _بالفعل تم رفعه مدير_', 1, 'md')
end
	else
         database:sadd(hash, result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _Promoted as Group Owner._', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _تم رفعه مدير_', 1, 'md')
end
	end
    end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,setowner_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ee][Tt][Oo][Ww][Nn][Ee][Rr] @(.*)$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Ss][Ee][Tt][Oo][Ww][Nn][Ee][Rr]) @(.*)$")} 
	function setowner_by_username(extra, result, success)
	if result.id_ then
	        database:sadd('bot:owners:'..msg.chat_id_, result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<b>User </b><code>'..result.id_..'</code> <b>Promoted as Group Owner.!</b>'
          else 
                        texts = '`📌¦` _اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦ ` _تم رفعه مدير_'
end
          else 
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<code>User not found!</code>'
          else 
                        texts = '`📌¦ `_ خطأ !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],setowner_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ee][Tt][Oo][Ww][Nn][Ee][Rr] (%d+)$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Ss][Ee][Tt][Oo][Ww][Nn][Ee][Rr]) (%d+)$")} 	
	        database:sadd('bot:owners:'..msg.chat_id_, ap[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..ap[2]..'* _Promoted as Group Owner._', 1, 'md')
else 
  	send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..ap[2]..'*\n`📌¦` _تم رفعه مدير_', 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('تنزيل مدير','remowner')
	if text:match("^[Rr][Ee][Mm][Oo][Ww][Nn][Ee][Rr]$") and is_admin(msg.sender_user_id_) and msg.reply_to_message_id_ then
	function deowner_by_reply(extra, result, success)
	local hash = 'bot:owners:'..msg.chat_id_
	if not database:sismember(hash, result.sender_user_id_) then
	     if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is not Owner._', 1, 'md')
    else 
               send(msg.chat_id_, msg.id_, 1,  '📌¦ _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦`_ليس مدير_', 1, 'md')
end
	else
         database:srem(hash, result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _Removed from ownerlist._', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1,  '📌¦ _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦`_تم تنزيله من المدراء_', 1, 'md')
end
	end
    end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,deowner_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Rr][Ee][Mm][Oo][Ww][Nn][Ee][Rr] @(.*)$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Rr][Ee][Mm][Oo][Ww][Nn][Ee][Rr]) @(.*)$")} 
	local hash = 'bot:owners:'..msg.chat_id_
	function remowner_by_username(extra, result, success)
	if result.id_ then
         database:srem(hash, result.id_)
	     if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<b>User </b><code>'..result.id_..'</code> <b>Removed from ownerlist</b>'
     else 
                   texts = '`📌¦` _اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦ ` _تم تنزيله من المدراء_'
end
          else 
	     if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<code>User not found!</code>'
          else 
                        texts = '`📌¦ `_ خطأ !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],remowner_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Rr][Ee][Mm][Oo][Ww][Nn][Ee][Rr] (%d+)$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	local hash = 'bot:owners:'..msg.chat_id_
	local ap = {string.match(text, "^([Rr][Ee][Mm][Oo][Ww][Nn][Ee][Rr]) (%d+)$")} 	
         database:srem(hash, ap[2])
	     if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..ap[2]..'* _Removed from ownerlist._', 1, 'md')
else 
  	send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..ap[2]..'*\n`📌¦` _تم تنزيله من المدراء_', 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
	          local text = msg.content_.text_:gsub('رفع ادمن للبوت','setadmin')
	if text:match("^[Ss][Ee][Tt][Aa][Dd][Mm][Ii][Nn]$") and is_sudo(msg) and msg.reply_to_message_id_ then
	function addadmin_by_reply(extra, result, success)
	local hash = 'bot:admins:'
	if database:sismember(hash, result.sender_user_id_) then
	     if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is Already Admin._', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '`📌¦ اﻟﻋﺿۆ :` *'..result.sender_user_id_..'*\n`📌¦ بالفعل ادمن للبوت`', 1, 'md')
end
	else
         database:sadd(hash, result.sender_user_id_)
	     if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _Added to admins._', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1,  '📌¦ _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦`_تم رفعه ادمن للبوت_', 1, 'md')
end
	end
    end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,addadmin_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ee][Tt][Aa][Dd][Mm][Ii][Nn] @(.*)$") and is_sudo(msg) then
	local ap = {string.match(text, "^([Ss][Ee][Tt][Aa][Dd][Mm][Ii][Nn]) @(.*)$")} 
	function addadmin_by_username(extra, result, success)
	if result.id_ then
	        database:sadd('bot:admins:', result.id_)
		     if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<b>User </b><code>'..result.id_..'</code> <b>Added to admins.!</b>'
          else 
                        texts = '`📌¦` _اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦ ` _تم رفعه ادمن للبوت_'
end
          else 
	     if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<code>User not found!</code>'
          else 
                        texts = '`📌¦ `_ خطأ !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],addadmin_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ee][Tt][Aa][Dd][Mm][Ii][Nn] (%d+)$") and is_sudo(msg) then
	local ap = {string.match(text, "^([Ss][Ee][Tt][Aa][Dd][Mm][Ii][Nn]) (%d+)$")} 	
	        database:sadd('bot:admins:', ap[2])
		     if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..ap[2]..'* _Added to admins._', 1, 'md')
else 
  	send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..ap[2]..'*\n`📌¦` _تم رفعه ادمن للبوت_', 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('تنزيل ادمن للبوت','remadmin')
	if text:match("^[Rr][Ee][Mm][Aa][Dd][Mm][Ii][Nn]$") and is_sudo(msg) and msg.reply_to_message_id_ then
	function deadmin_by_reply(extra, result, success)
	local hash = 'bot:admins:'
	if not database:sismember(hash, result.sender_user_id_) then
		     if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is not Admin._', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1,  '📌¦ _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦`_ بالفعل ليس ادمن للبوت_', 1, 'md')
end
	else
         database:srem(hash, result.sender_user_id_)
		     if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _Removed from Admins!._', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦`_تم تنزيله من ادمنيه البوت_', 1, 'md')
end
	end
    end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,deadmin_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Rr][Ee][Mm][Aa][Dd][Mm][Ii][Nn] @(.*)$") and is_sudo(msg) then
	local hash = 'bot:admins:'
	local ap = {string.match(text, "^([Rr][Ee][Mm][Aa][Dd][Mm][Ii][Nn]) @(.*)$")} 
	function remadmin_by_username(extra, result, success)
	if result.id_ then
         database:srem(hash, result.id_)
		     if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<b>User </b><code>'..result.id_..'</code> <b>Removed from Admins!</b>'
          else 
                        texts = '`📌¦` _اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦ ` _تم تنزيله من ادمنيه البوت_'
end
          else 
		     if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<code>User not found!</code>'
          else 
                        texts = '`📌¦ `_ خطأ !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],remadmin_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Rr][Ee][Mm][Aa][Dd][Mm][Ii][Nn] (%d+)$") and is_sudo(msg) then
	local hash = 'bot:admins:'
	local ap = {string.match(text, "^([Rr][Ee][Mm][Aa][Dd][Mm][Ii][Nn]) (%d+)$")} 	
         database:srem(hash, ap[2])
		     if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..ap[2]..'* Removed from Admins!_', 1, 'md')
else 
  	send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..ap[2]..'*\n`📌¦` _تم تنزيله من ادمنيه البوت_', 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Mm][Oo][Dd][Ll][Ii][Ss][Tt]") or text:match("^الادمنيه") and is_mod(msg.sender_user_id_, msg.chat_id_) then
    local hash =  'bot:mods:'..msg.chat_id_
	local list = database:smembers(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "<b>Mod List:</b>\n\n"
else 
  text ="`📌¦` _قائمه الادمنيه _ : \n\n"
  end
	for k,v in pairs(list) do
	local user_info = database:hgetall('user:'..v)
		if user_info and user_info.username then
			local username = user_info.username
			text = text..k.." - @"..username.." ["..v.."]\n"
		else
			text = text..k.." - "..v.."\n"
		end
	end
	if #list == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "<b>Mod List is empty !</b>"
              else 
                text = "`📌¦` _ لايوجد ادمنيه _"
end
    end
	send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
  end

	if text:match("^[Bb][Aa][Dd][Ll][Ii][Ss][Tt]$") or text:match("^قائمه المنع$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local hash = 'bot:filters:'..msg.chat_id_
      if hash then
         local names = database:hkeys(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "<b>bad List:</b>\n\n"
else 
  text ="`📌¦` _قائمه الكلمات الممنوعه _ : \n\n"
  end    for i=1, #names do
      text = text..'🚫¦ '..names[i]..'\n'
    end
	if #names == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "<b>bad List is empty !</b>"
              else 
                text = "`📌¦` _ لايوجد كلمات ممنوعه _"
end
    end
		  send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
       end
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ii][Ll][Ee][Nn][Tt][Ll][Ii][Ss][Tt]") or text:match("^المكتومين") and is_mod(msg.sender_user_id_, msg.chat_id_) then
    local hash =  'bot:muted:'..msg.chat_id_
	local list = database:smembers(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "<b>Silent List:</b>\n\n"
else 
  text = "`📌¦` _المكتومين هم _ : \n\n"
end	
for k,v in pairs(list) do
	local user_info = database:hgetall('user:'..v)
		if user_info and user_info.username then
			local username = user_info.username
			text = text..k.." - @"..username.." ["..v.."]\n"
		else
			text = text..k.." - "..v.."\n"
		end
	end
	if #list == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "<b>Mod List is empty !</b>"
              else 
                text = "`📌¦` _ لايوجد مكتومين _"
end
end
	send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Oo][Ww][Nn][Ee][Rr][Ss]$") or text:match("^[Oo][Ww][Nn][Ee][Rr][Ll][Ii][Ss][Tt]$") or text:match("^المدراء$") and is_sudo(msg) then
    local hash =  'bot:owners:'..msg.chat_id_
	local list = database:smembers(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "<b>owner List:</b>\n\n"
else 
  text ="`📌¦ `_المدراء _ : \n\n"
end	
for k,v in pairs(list) do
	local user_info = database:hgetall('user:'..v)
		if user_info and user_info.username then
			local username = user_info.username
			text = text..k.." - @"..username.." ["..v.."]\n"
		else
			text = text..k.." - "..v.."\n"
		end
	end
	if #list == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "<b>owner List is empty !</b>"
              else 
                text = "`📌¦` _ لايوجد مدراء_"
end
end
	send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Bb][Aa][Nn][Ll][Ii][Ss][Tt]$") or text:match("^المحظورين$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
    local hash =  'bot:banned:'..msg.chat_id_
	local list = database:smembers(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "<b>ban List:</b>\n\n"
else 
  text ="`📌¦ `_قائمه المحظورين _ : \n\n"
end	
for k,v in pairs(list) do
	local user_info = database:hgetall('user:'..v)
		if user_info and user_info.username then
			local username = user_info.username
			text = text..k.." - @"..username.." ["..v.."]\n"
		else
			text = text..k.." - "..v.."\n"
		end
	end
	if #list == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "<b>ban List is empty !</b>"
              else 
                text = "`📌¦` _ لايوجد محظورين_"
end
end
	send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
end

  if msg.content_.text_:match("^[Gg][Bb][Aa][Nn][Ll][Ii][Ss][Tt]$") or msg.content_.text_:match("^قائمه العام$") and is_sudo(msg) then
    local hash =  'bot:gbanned:'
    local list = database:smembers(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "<b>Gban List:</b>\n\n"
else 
   text ="`📌¦` _قائمه المحظورين عام _ : \n\n"
end	
for k,v in pairs(list) do
    local user_info = database:hgetall('user:'..v)
    if user_info and user_info.username then
    local username = user_info.username
      text = text..k.." - @"..username.." ["..v.."]\n"
      else
      text = text..k.." - "..v.."\n"
          end
end
            if #list == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "<b>Gban List is empty !</b>"
              else 
                text = "`📌¦` _لايوجد محظورين عام_"
end
end
	send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
          end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Aa][Dd][Mm][Ii][Nn][Ll][Ii][Ss][Tt]$") or text:match("^ادمنيه البوت$") and is_sudo(msg) then
    local hash =  'bot:admins:'
	local list = database:smembers(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "<b>Admin List:</b>\n\n"
else 
  text = "`📌¦`_ادمنيه البوت هم_ :\n\n"
  end
for k,v in pairs(list) do
	local user_info = database:hgetall('user:'..v)
		if user_info and user_info.username then
			local username = user_info.username
			text = text..k.." - @"..username.." ["..v.."]\n"
		else
			text = text..k.." - "..v.."\n"
		end
	end
	if #list == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "<b>Admin List is empty !</b>"
              else 
                text = "`📌¦` _لا يوجد ادمنيه للبوت_"
end
end
	send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
    end
	-----------------------------------------------------------------------------------------------
    if text:match("^[Ii][Dd]$") or text:match("^ايدي$") and msg.reply_to_message_id_ ~= 0 then
      function id_by_reply(extra, result, success)
	  local user_msgs = database:get('user:msgs'..result.chat_id_..':'..result.sender_user_id_)
        send(msg.chat_id_, msg.id_, 1, "`"..result.sender_user_id_.."`", 1, 'md')
        end
   getMessage(msg.chat_id_, msg.reply_to_message_id_,id_by_reply)
  end
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('ايدي','id')
    if text:match("^[Ii][Dd] @(.*)$") then
	local ap = {string.match(text, "^([Ii][Dd]) @(.*)$")} 
	function id_by_username(extra, result, success)
	if result.id_ then
            texts = '`'..result.id_..'`'
            else 
            texts = '<code>User not found!</code>'
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],id_by_username)
    end
    
    if text:match("^[Rr][Ee][Ss] @(.*)$") then
	local ap = {string.match(text, "^([Rr][Ee][Ss]) @(.*)$")} 
	function id_by_username(extra, result, success)
	if result.id_ then 
            texts = '*> Username* : @'..ap[2]..'\n*> ID* : `'..result.id_..'`'
            else 
            texts = '<code>User not found!</code>'
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],id_by_username)
    end
    -----------------------------------------------------------------------------------------------
    local text = msg.content_.text_:gsub('طرد','kick')
  if text:match("^[Kk][Ii][Cc][Kk]$") and msg.reply_to_message_id_ and is_mod(msg.sender_user_id_, msg.chat_id_) then
      function kick_reply(extra, result, success)
	if is_mod(result.sender_user_id_, result.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick] Moderators!!*', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦` _لا تستطيع طرد الادمنيه_', 1, 'md')
end
  else
                if database:get('lang:gp:'..msg.chat_id_) then
        send(msg.chat_id_, msg.id_, 1, '*User* _'..result.sender_user_id_..'_ *Kicked.*', 1, 'md')
      else 
        send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _تم طرده_', 1, 'md')
end
        chat_kick(result.chat_id_, result.sender_user_id_)
        end
	end
   getMessage(msg.chat_id_,msg.reply_to_message_id_,kick_reply)
  end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Kk][Ii][Cc][Kk] @(.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local apki = {string.match(text, "^([Kk][Ii][Cc][Kk]) @(.*)$")} 
	function kick_by_username(extra, result, success)
	if result.id_ then
	if is_mod(result.id_, msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick] Moderators!!*', 1, 'md')
       else
send(msg.chat_id_, msg.id_, 1, '`📌¦` _لا تستطيع طرد الادمنيه_', 1, 'md')
end
    else
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<b>User </b><code>'..result.id_..'</code> <b>Kicked.!</b>'
else
                        texts = '`📌¦` _اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦` _تم طرده_'
end
		 chat_kick(msg.chat_id_, result.id_)
	end
          else 
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<code>User not found!</code>'
          else
                        texts = '`📌¦ `_ خطأ !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(apki[2],kick_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Kk][Ii][Cc][Kk] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local apki = {string.match(text, "^([Kk][Ii][Cc][Kk]) (%d+)$")}
	if is_mod(apki[2], msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick] Moderators!!*', 1, 'md')
       else
send(msg.chat_id_, msg.id_, 1, '`📌¦` _لا تستطيع طرد الادمنيه_', 1, 'md')
end
    else
		 chat_kick(msg.chat_id_, apki[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..apki[2]..'* _Kicked._', 1, 'md')
else
    send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..apki[2]..'*\n`📌¦` _تم طرده_', 1, 'md')
  	end
	end
end
          -----------------------------------------------------------------------------------------------
 local text = msg.content_.text_:gsub('اضافه','invite')
   if text:match("^[Ii][Nn][Vv][Ii][Tt][Ee]$") and msg.reply_to_message_id_ ~= 0 and is_sudo(msg) then
   function inv_reply(extra, result, success)
    add_user(result.chat_id_, result.sender_user_id_, 5)
                if database:get('lang:gp:'..msg.chat_id_) then
        send(msg.chat_id_, msg.id_, 1, '*User* _'..result.sender_user_id_..'_ *Add it.*', 1, 'md')
      else 
        send(msg.chat_id_, msg.id_, 1,  '`📌¦` _اﻟﻋﺿۆ_ : *'..result.sender_user_id_..'*\n`📌¦` _تم اضافته للمجموعه_', 1, 'md')
   end
   end
    getMessage(msg.chat_id_, msg.reply_to_message_id_,inv_reply)
   end
          -----------------------------------------------------------------------------------------------
   if text:match("^[Ii][Nn][Vv][Ii][Tt][Ee] @(.*)$") and is_sudo(msg) then
    local apss = {string.match(text, "^([Ii][Nn][Vv][Ii][Tt][Ee]) @(.*)$")}
    function invite_by_username(extra, result, success)
     if result.id_ then
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<b>User </b><code>'..result.id_..'</code> <b>Add it!</b>'
else
            texts = '`📌¦` _اﻟﻋﺿۆ_ : '..result.id_..'\n`📌¦` _تم اضافته للمجموعه_'
end
    add_user(msg.chat_id_, result.id_, 5)
          else 
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '<code>User not found!</code>'
          else
            texts = '`📌¦ `_ خطأ !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
    resolve_username(apss[2],invite_by_username)
 end
        -----------------------------------------------------------------------------------------------
    if text:match("^[Ii][Nn][Vv][Ii][Tt][Ee] (%d+)$") and is_sudo(msg) then
      local apee = {string.match(text, "^([Ii][Nn][Vv][Ii][Tt][Ee]) (%d+)$")}
      add_user(msg.chat_id_, apee[2], 5)
                  if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..apee[2]..'* _Add it._', 1, 'md')
else
    send(msg.chat_id_, msg.id_, 1, '`📌¦` _اﻟﻋﺿۆ_ : *'..apee[2]..'*\n`📌¦` _تم اضافته للمجموعه_', 1, 'md')
  	end
    end
	-----------------------------------------------------------------------------------------------

  if text:match("^inv$") and msg.reply_to_message_id_ and is_sudo(msg) then
      function inv_reply(extra, result, success)
           add_user(result.chat_id_, result.sender_user_id_, 5)
        end
   getMessage(msg.chat_id_, msg.reply_to_message_id_,inv_reply)
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('جلب صوره','getpro')
    if text:match("^getpro (%d+)$") and msg.reply_to_message_id_ == 0  then
		local pronumb = {string.match(text, "^(getpro) (%d+)$")} 
local function gpro(extra, result, success)
--vardump(result)
   if pronumb[2] == '1' then
   if result.photos_[0] then
      sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[0].sizes_[1].photo_.persistent_id_)
   else
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "You Have'nt Profile Photo!!", 1, 'md')
    else 
            send(msg.chat_id_, msg.id_, 1, "`📌¦` _لاتوجد صوره في حسابك_", 1, 'md')
end
   end
   elseif pronumb[2] == '2' then
   if result.photos_[1] then
      sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[1].sizes_[1].photo_.persistent_id_)
   else
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "You Have'nt 2 Profile Photo!!", 1, 'md')
    else 
            send(msg.chat_id_, msg.id_, 1, "`📌¦` _لاتوجد صوره ثانيه في حسابك_", 1, 'md')
end
   end
   elseif pronumb[2] == '3' then
   if result.photos_[2] then
      sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[2].sizes_[1].photo_.persistent_id_)
   else
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "You Have'nt 3 Profile Photo!!", 1, 'md')
    else 
            send(msg.chat_id_, msg.id_, 1, "`📌¦` _لاتوجد صوره ثالثه في حسابك_", 1, 'md')
end
   end
   elseif pronumb[2] == '4' then
      if result.photos_[3] then
      sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[3].sizes_[1].photo_.persistent_id_)
   else
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "You Have'nt 4 Profile Photo!!", 1, 'md')
    else 
            send(msg.chat_id_, msg.id_, 1, "`📌¦` _لاتوجد صوره رابعه في حسابك_", 1, 'md')
end
   end
   elseif pronumb[2] == '5' then
   if result.photos_[4] then
      sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[4].sizes_[1].photo_.persistent_id_)
   else
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "You Have'nt 5 Profile Photo!!", 1, 'md')
    else 
            send(msg.chat_id_, msg.id_, 1, "`📌¦` _لاتوجد صوره خامسه في حسابك_", 1, 'md')
end
   end
   elseif pronumb[2] == '6' then
   if result.photos_[5] then
      sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[5].sizes_[1].photo_.persistent_id_)
   else
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "You Have'nt 6 Profile Photo!!", 1, 'md')
    else 
            send(msg.chat_id_, msg.id_, 1, "`📌¦` _لاتوجد صوره سادسه في حسابك_", 1, 'md')
end
   end
   elseif pronumb[2] == '7' then
   if result.photos_[6] then
      sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[6].sizes_[1].photo_.persistent_id_)
   else
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "You Have'nt 7 Profile Photo!!", 1, 'md')
    else 
            send(msg.chat_id_, msg.id_, 1, "`📌¦` _لاتوجد صوره سابعه في حسابك_", 1, 'md')
end
   end
   elseif pronumb[2] == '8' then
   if result.photos_[7] then
      sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[7].sizes_[1].photo_.persistent_id_)
   else
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "You Have'nt 8 Profile Photo!!", 1, 'md')
    else 
            send(msg.chat_id_, msg.id_, 1, "`📌¦` _لاتوجد صوره ثامنه في حسابك_", 1, 'md')
end
   end
   elseif pronumb[2] == '9' then
   if result.photos_[8] then
      sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[8].sizes_[1].photo_.persistent_id_)
   else
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "You Have'nt 9 Profile Photo!!", 1, 'md')
    else 
            send(msg.chat_id_, msg.id_, 1, "`📌¦` _لاتوجد صوره تاسعه في حسابك_", 1, 'md')
end
   end
   elseif pronumb[2] == '10' then
   if result.photos_[9] then
      sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[9].sizes_[1].photo_.persistent_id_)
   else
                     if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "_You Have'nt 10 Profile Photo!!_", 1, 'md')
    else 
            send(msg.chat_id_, msg.id_, 1, "`📌¦` _لاتوجد صوره عاشره في حسابك_", 1, 'md')
end
   end
 else
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "*I just can get last 10 profile photos!:(*", 1, 'md')
    else 
            send(msg.chat_id_, msg.id_, 1, "`📌¦` _لا تستطيع جلب اكثر من 10 صور_", 1, 'md')
end
   end
   end
   tdcli_function ({
    ID = "GetUserProfilePhotos",
    user_id_ = msg.sender_user_id_,
    offset_ = 0,
    limit_ = pronumb[2]
  }, gpro, nil)
	end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ll][Oo][Cc][Kk] (.*)$") or text:match("^قفل (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local KOKE1 = {string.match(text, "^([Ll][Oo][Cc][Kk]) (.*)$")} 
	local KOKE = {string.match(text, "^(قفل) (.*)$")} 
    if KOKE1[2] == "edit" or KOKE[2] == "التعديل" then
              if not database:get('editmsg'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, "_> Edit Has been_ *locked*", 1, 'md')
                else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل التعديل _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
                  end
                database:set('editmsg'..msg.chat_id_,'delmsg')
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> Lock edit is already_ *locked*', 1, 'md')
                else
send(msg.chat_id_, 0, 1,'`📌¦`_ التعديل بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
                end
              end
            end
   if KOKE1[2] == "bots" or KOKE[2] == "البوتات" then
              if not database:get('bot:bots:mute'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, "_> Bots Has been_ *locked*", 1, 'md')
                else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل البوتات _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
                database:set('bot:bots:mute'..msg.chat_id_,true)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                 send(msg.chat_id_, msg.id_, 1, "_> Bots is Already_ *locked*", 1, 'md')
                else
send(msg.chat_id_, 0, 1,'`📌¦`_ البوتات بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
                end
              end
            end
           if KOKE1[2] == "flood ban" or KOKE[2] == "التكرار بالطرد" then
                if database:get('lang:gp:'..msg.chat_id_) then
             send(msg.chat_id_, msg.id_, 1, '*Flood Ban* has been *locked*', 1, 'md')
             else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل التكرار بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
                database:del('anti-flood:'..msg.chat_id_)
              end
                end
                   if KOKE1[2] == "flood mute" or KOKE[2] == "التكرار بالكتم" then
                if database:get('lang:gp:'..msg.chat_id_) then
                send(msg.chat_id_, msg.id_, 1, '*Flood warn* has been *locked*', 1, 'md')
                   else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل التكرار بالكتم _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
                 database:del('anti-flood:warn'..msg.chat_id_)
                 end
              end
        if KOKE1[2] == "pin" or KOKE[2] == "التثبيت" and is_owner(msg.sender_user_id_, msg.chat_id_) then
              if not database:get('bot:pin:mute'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                 send(msg.chat_id_, msg.id_, 1, "_> Pin Has been_ *locked*", 1, 'md')
                else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل التثبيت _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
                end
                database:set('bot:pin:mute'..msg.chat_id_,true)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                            send(msg.chat_id_, msg.id_, 1, "_> Pin is Already_ *locked*", 1, 'md')
                else
send(msg.chat_id_, 0, 1,'`📌¦`_ التثبيت بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
                end
              end
            end
        if KOKE1[2] == "pin warn" or KOKE[2] == "التثبيت بالتحذير" and is_owner(msg.sender_user_id_, msg.chat_id_) then
              if not database:get('bot:pin:warn'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                 send(msg.chat_id_, msg.id_, 1, "_> Pin warn Has been_ *locked*", 1, 'md')
                else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل التثبيت بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
                end
                database:set('bot:pin:warn'..msg.chat_id_,true)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                            send(msg.chat_id_, msg.id_, 1, "_> Pin warn is Already_ *locked*", 1, 'md')
                else
send(msg.chat_id_, 0, 1,'`📌¦`_ التثبيت بالتحذير بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
              end
            end
              end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('وضع تكرار بالطرد','flood ban')
	if text:match("^[Ff][Ll][Oo][Oo][Dd] [Bb][Aa][Nn] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local floodmax = {string.match(text, "^([Ff][Ll][Oo][Oo][Dd] [Bb][Aa][Nn]) (%d+)$")} 
	if tonumber(floodmax[2]) < 2 then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Wrong number*,_range is  [2-99999]_', 1, 'md')
else
           send(msg.chat_id_, msg.id_, 1, '`📌¦ `_ضع عدد من_ _[2-99999]_', 1, 'md')
end
	else
    database:set('flood:max:'..msg.chat_id_,floodmax[2])
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Flood has been set to_ *'..floodmax[2]..'*', 1, 'md')
        else
         send(msg.chat_id_, msg.id_, 1, '`📌¦` _تم وضع التكرار بالطرد للعدد_ *'..floodmax[2]..'*', 1, 'md')
end
	end
end

          local text = msg.content_.text_:gsub('وضع تكرار بالكتم','flood mute')
	if text:match("^[Ff][Ll][Oo][Oo][Dd] [Mm][Uu][Tt][Ee] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local floodmax = {string.match(text, "^([Ff][Ll][Oo][Oo][Dd] [Mm][Uu][Tt][Ee]) (%d+)$")} 
	if tonumber(floodmax[2]) < 2 then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Wrong number*,_range is  [2-99999]_', 1, 'md')
       else 
           send(msg.chat_id_, msg.id_, 1, '`📌¦ `_ضع عدد من_ _[2-99999]_', 1, 'md')
end
	else
    database:set('flood:max:warn'..msg.chat_id_,floodmax[2])
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Flood Warn has been set to_ *'..floodmax[2]..'*', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦` _تم وضع التكرار بالكتم للعدد_ *'..floodmax[2]..'*', 1, 'md')
end
	end
end
          local text = msg.content_.text_:gsub('وضع كلايش بالمسح','spam del')
if text:match("^[Ss][Pp][Aa][Mm] [Dd][Ee][Ll] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
local sensspam = {string.match(text, "^([Ss][Pp][Aa][Mm] [Dd][Ee][Ll]) (%d+)$")}
if tonumber(sensspam[2]) < 40 then
                if database:get('lang:gp:'..msg.chat_id_) then
send(msg.chat_id_, msg.id_, 1, '*Wrong number*,_range is  [40-99999]_', 1, 'md')
else 
send(msg.chat_id_, msg.id_, 1, '`📌¦ `_ضع عدد من_ _[2-99999]_', 1, 'md')
end
 else
database:set('bot:sens:spam'..msg.chat_id_,sensspam[2])
                if database:get('lang:gp:'..msg.chat_id_) then
send(msg.chat_id_, msg.id_, 1, '_> Spam has been set to_ *'..sensspam[2]..'*', 1, 'md')
else 
send(msg.chat_id_, msg.id_, 1, ' `📌¦` _تم وضع الكليشه للعدد_ *'..sensspam[2]..'*', 1, 'md')
end
end
end
          local text = msg.content_.text_:gsub('وضع كلايش بالتحذير','spam warn')
if text:match("^[Ss][Pp][Aa][Mm] [Ww][Aa][Rr][Nn] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
local sensspam = {string.match(text, "^([Ss][Pp][Aa][Mm] [Ww][Aa][Rr][Nn]) (%d+)$")}
if tonumber(sensspam[2]) < 40 then
                if database:get('lang:gp:'..msg.chat_id_) then
send(msg.chat_id_, msg.id_, 1, '*Wrong number*,_range is  [40-99999]_', 1, 'md')
else 
send(msg.chat_id_, msg.id_, 1, '`📌¦ `_ضع عدد من_ _[2-99999]_', 1, 'md')
end
 else
database:set('bot:sens:spam:warn'..msg.chat_id_,sensspam[2])
                if database:get('lang:gp:'..msg.chat_id_) then
send(msg.chat_id_, msg.id_, 1, '_> Spam Warn has been set to_ *'..sensspam[2]..'*', 1, 'md')
else 
send(msg.chat_id_, msg.id_, 1, ' `📌¦` _تم وضع الكليشه للعدد_ *'..sensspam[2]..'*', 1, 'md')
end
end
end

	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('وضع زمن التكرار','flood time')
	if text:match("^[Ff][Ll][Oo][Oo][Dd] [Tt][Ii][Mm][Ee] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local floodt = {string.match(text, "^([Ff][Ll][Oo][Oo][Dd] [Tt][Ii][Mm][Ee]) (%d+)$")} 
	if tonumber(floodt[2]) < 2 then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Wrong number*,_range is  [2-99999]_', 1, 'md')
       else 
           send(msg.chat_id_, msg.id_, 1, '`📌¦ `_ضع عدد من_ _[2-99999]_', 1, 'md')
end
	else
    database:set('flood:time:'..msg.chat_id_,floodt[2])
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Flood has been set to_ *'..floodt[2]..'*', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦` _تم وضع زمن التكرار للعدد_ *'..floodt[2]..'*', 1, 'md')
end
	end
	end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Hh][Oo][Ww] [Ee][Dd][Ii][Tt]$") or text:match("^كشف التعديل$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
         database:set('editmsg'..msg.chat_id_,'didam')
         send(msg.chat_id_, msg.id_, 1, '*Done*\n_Activation detection has been activated_', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '`📌¦` _تم تفعيل كشف التعديل_', 1, 'md')
end
	end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ee][Tt][Ll][Ii][Nn][Kk]") or text:match("^وضع رابط") and is_mod(msg.sender_user_id_, msg.chat_id_) then
         database:set("bot:group:link"..msg.chat_id_, 'Waiting For Link!\nPls Send Group Link')
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Please Send Group Link Now!*', 1, 'md')
else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_قم بارسال الرابط الان_', 1, 'md')
end
	end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ll][Ii][Nn][Kk]$") or text:match("^الرابط$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local link = database:get("bot:group:link"..msg.chat_id_)
	  if link then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '<b>Group link:</b>\n'..link, 1, 'html')
       else 
                   send(msg.chat_id_, msg.id_, 1, '`📌¦` _رابط المجموعه_ :\n'..link, 1, 'md')
end
	  else
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*There is not link set yet. Please add one by #setlink .*', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '`📌¦ `_لايوجد رابط محفوظ ارسل وضع رابط _', 1, 'md')
end
	  end
 	end
	
	if text:match("^[Ww][Ll][Cc] [Oo][Nn]$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '#Done\nWelcome *Enabled* In This Supergroup.', 1, 'md')
		 database:set("bot:welcome"..msg.chat_id_,true)
	end
	if text:match("^[Ww][Ll][Cc] [Oo][Ff][Ff]$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '#Done\nWelcome *Disabled* In This Supergroup.', 1, 'md')
		 database:del("bot:welcome"..msg.chat_id_)
	end
	
	if text:match("^تفعيل الترحيب$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم تفعيل الترحيب بالمجموعه_', 1, 'md')
		 database:set("bot:welcome"..msg.chat_id_,true)
	end
	if text:match("^تعطيل الترحيب$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم تعطيل الترحيب بالمجموعه_', 1, 'md')
		 database:del("bot:welcome"..msg.chat_id_)
	end

	if text:match("^[Ss][Ee][Tt] [Ww][Ll][Cc] (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local welcome = {string.match(text, "^([Ss][Ee][Tt] [Ww][Ll][Cc]) (.*)$")} 
         send(msg.chat_id_, msg.id_, 1, '*Welcome Msg Has Been Saved!*\nWlc Text:\n\n`'..welcome[2]..'`', 1, 'md')
		 database:set('welcome:'..msg.chat_id_,welcome[2])
	end
	
	if text:match("^وضع ترحيب (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local welcome = {string.match(text, "^(وضع ترحيب) (.*)$")} 
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم وضع الترحيب_ :\n\n'..welcome[2]..' ', 1, 'md')
		 database:set('welcome:'..msg.chat_id_,welcome[2])
	end

          local text = msg.content_.text_:gsub('حذف الترحيب','del wlc')
	if text:match("^[Dd][Ee][Ll] [Ww][Ll][Cc]$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Welcome Msg Has Been Deleted!*', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم حذف الترحيب_', 1, 'md')
end
		 database:del('welcome:'..msg.chat_id_)
	end
	
          local text = msg.content_.text_:gsub('جلب الترحيب','get wlc')
	if text:match("^[Gg][Ee][Tt] [Ww][Ll][Cc]$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local wel = database:get('welcome:'..msg.chat_id_)
	if wel then
         send(msg.chat_id_, msg.id_, 1, wel, 1, 'md')
    else 
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, 'Welcome msg not saved!', 1, 'md')
else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_لايوجد ترحيب محفوظ_', 1, 'md')
end
	end
	end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('منع','bad')
	if text:match("^[Bb][Aa][Dd] (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local filters = {string.match(text, "^([Bb][Aa][Dd]) (.*)$")} 
    local name = string.sub(filters[2], 1, 50)
          database:hset('bot:filters:'..msg.chat_id_, name, 'filtered')
                if database:get('lang:gp:'..msg.chat_id_) then
		  send(msg.chat_id_, msg.id_, 1, "*New Word baded!*\n--> `"..name.."`", 1, 'md')
else 
  		  send(msg.chat_id_, msg.id_, 1, "`📌¦ `#"..name.." \n`📌¦ `_تم اضافتها لقائمه المنع_", 1, 'md')
end
	end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('الغاء منع','unbad')
	if text:match("^[Uu][Nn][Bb][Aa][Dd] (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local rws = {string.match(text, "^([Uu][Nn][Bb][Aa][Dd]) (.*)$")} 
    local name = string.sub(rws[2], 1, 50)
          database:hdel('bot:filters:'..msg.chat_id_, rws[2])
                if database:get('lang:gp:'..msg.chat_id_) then
		  send(msg.chat_id_, msg.id_, 1, "`"..rws[2].."` *Removed From baded List!*", 1, 'md')
else 
  		  send(msg.chat_id_, msg.id_, 1, "`📌¦ `#"..rws[2].." \n`📌¦ `_تم حذفها من قائمه المنع_", 1, 'md')
end
	end 
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('اذاعه','bc')
	if text:match("^bc (.*)$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
    local gps = database:scard("bot:groups") or 0
    local gpss = database:smembers("bot:groups") or 0
	local rws = {string.match(text, "^(bc) (.*)$")} 
	for i=1, #gpss do
		  send(gpss[i], 0, 1, rws[2], 1, 'md')
  end
                if database:get('lang:gp:'..msg.chat_id_) then
                   send(msg.chat_id_, msg.id_, 1, '*Done*\n_Your Msg Send to_ `'..gps..'` _Groups_', 1, 'md')
                   else
                     send(msg.chat_id_, msg.id_, 1, '`📌¦ `_الرساله تم نشرها في_  *'..gps..'*'..' _كروب_', 1, 'md')
end
	end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Gg][Rr][Oo][Uu][Pp][Ss]$") or text:match("^الكروبات$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
    local gps = database:scard("bot:groups")
	local users = database:scard("bot:userss")
    local allmgs = database:get("bot:allmsgs")
                if database:get('lang:gp:'..msg.chat_id_) then
                   send(msg.chat_id_, msg.id_, 1, '*Groups :* `'..gps..'`', 1, 'md')
                 else
                   send(msg.chat_id_, msg.id_, 1, '`📌¦ `_عدد الكروبات_  *'..gps..'*'..' _كروب_', 1, 'md')
end
	end
	
if  text:match("^[Mm][Ss][Gg]$") or text:match("^رسائلي$") and msg.reply_to_message_id_ == 0  then
local user_msgs = database:get('user:msgs'..msg.chat_id_..':'..msg.sender_user_id_)
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "*Msgs : * `"..user_msgs.."`", 1, 'md')
    else 
      send(msg.chat_id_, msg.id_, 1, "📌¦ _عدد رسائلك هي_ : *"..user_msgs.."*  _رساله_", 1, 'md')
end
	end
	-----------------------------------------------------------------------------------------------
  	if text:match("^[Uu][Nn][Ll][Oo][Cc][Kk] (.*)$") or text:match("^فتح (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local unlockpt = {string.match(text, "^([Uu][Nn][Ll][Oo][Cc][Kk]) (.*)$")} 
	local TSHAKEUN = {string.match(text, "^(فتح) (.*)$")} 
                if unlockpt[2] == "edit" or TSHAKEUN[2] == "التعديل" then
              if database:get('editmsg'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_> Edit Has been_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح التعديل _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
                end
                database:del('editmsg'..msg.chat_id_)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> Lock edit is already_ *Unlocked*', 1, 'md')
                else
                  send(msg.chat_id_, 0, 1,'`📌¦`_ التعديل بالفعل مفتوح _'..'\n'..'📌¦ _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
                end
              end
            end
                if unlockpt[2] == "bots" or TSHAKEUN[2] == "البوتات" then
              if database:get('bot:bots:mute'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_> Bots Has been_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح البوتات _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
                end
                database:del('bot:bots:mute'..msg.chat_id_)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_> Bots is Already_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, 0, 1,'`📌¦`_ البوتات بالفعل مفتوحه _'..'\n'..'📌¦ _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
                end
              end
            end
	              if unlockpt[2] == "flood ban" or TSHAKEUN[2] == "التكرار بالطرد" then
                if database:get('lang:gp:'..msg.chat_id_) then
                   send(msg.chat_id_, msg.id_, 1, '*Flood Ban* has been *unlocked*', 1, 'md')
                 else
                  send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح التكرار بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
                   database:set('anti-flood:'..msg.chat_id_,true)
            	  end
            	  end
            	  if unlockpt[2] == "flood mute" or TSHAKEUN[2] == "التكرار بالكتم" then
                if database:get('lang:gp:'..msg.chat_id_) then
                   send(msg.chat_id_, msg.id_, 1, '*Flood warn* has been *unlocked*', 1, 'md')
                 else
                  send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح التكرار بالكتم _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
                   database:set('anti-flood:warn'..msg.chat_id_,true)
             	  end
             	  end
                if unlockpt[2] == "pin" or TSHAKEUN[2] == "التثبيت" and is_owner(msg.sender_user_id_, msg.chat_id_) then
              if database:get('bot:pin:mute'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_> Pin Has been_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح التثبيت _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
                end
                database:del('bot:pin:mute'..msg.chat_id_)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_> Pin is Already_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, 0, 1,'`📌¦`_ التثبيت بالفعل مفتوح _'..'\n'..'📌¦ _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
                end
              end
            end
                if unlockpt[2] == "pin warn" or TSHAKEUN[2] == "التثبيت بالتحذير" and is_owner(msg.sender_user_id_, msg.chat_id_) then
              if database:get('bot:pin:warn'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_> Pin warn Has been_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح التثبيت بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
                end
                database:del('bot:pin:warn'..msg.chat_id_)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_> Pin warn is Already_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, 0, 1,'`📌¦`_ التثبيت بالتحذير بالفعل مفتوح _'..'\n'..'📌¦ _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
                end
              end
            end
              end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('قفل الكل بالثواني','lock all s')
  	if text:match("^[Ll][Oo][Cc][Kk] [Aa][Ll][Ll] [Ss] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local mutept = {string.match(text, "^[Ll][Oo][Cc][Kk] [Aa][Ll][Ll] [Ss] (%d+)$")}
	    		database:setex('bot:muteall'..msg.chat_id_, tonumber(mutept[1]), true)
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Group muted for_ *'..mutept[1]..'* _seconds!_', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦`_ تم قفل كل الوسائط لمده _ *'..mutept[1]..'* _ثواني_'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
end
	end

          local text = msg.content_.text_:gsub('قفل الكل بالساعه','lock all h')
    if text:match("^[Ll][Oo][Cc][Kk] [Aa][Ll][Ll] [Hh]  (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
        local mutept = {string.match(text, "^[Ll][Oo][Cc][Kk] [Aa][Ll][Ll] [Hh] (%d+)$")}
        local hour = string.gsub(mutept[1], 'h', '')
        local num1 = tonumber(hour) * 3600
        local num = tonumber(num1)
            database:setex('bot:muteall'..msg.chat_id_, num, true)
                if database:get('lang:gp:'..msg.chat_id_) then
              send(msg.chat_id_, msg.id_, 1, "> Lock all has been enable for "..mutept[1].." hours !", 'md')
       else 
              send(msg.chat_id_, msg.id_, 1, '`📌¦`_ تم قفل كل الوسائط لمده _ *'..mutept[1]..'* _ساعه_'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
end
     end
	-----------------------------------------------------------------------------------------------
  	if text:match("^[Ll][Oo][Cc][Kk] (.*)$") or text:match("^قفل (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local mutept = {string.match(text, "^([Ll][Oo][Cc][Kk]) (.*)$")} 
	local TSHAKE = {string.match(text, "^(قفل) (.*)$")}
      if mutept[2] == "all" or TSHAKE[2] == "الكل" then
	  if not database:get('bot:muteall'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> mute all has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الوسائط _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
        end
         database:set('bot:muteall'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_> mute all is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الوسائط بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "all warn" or TSHAKE[2] == "الكل بالتحذير" then
	  if not database:get('bot:muteallwarn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> mute all warn has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الوسائط بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
end
         database:set('bot:muteallwarn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> mute all warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الوسائط بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "all ban" or TSHAKE[2] == "الكل بالطرد" then
	  if not database:get('bot:muteallban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> mute all ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الوسائط بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
end
         database:set('bot:muteallban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> mute all ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الوسائط بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "text" or TSHAKE[2] == "الدردشه" then
	  if not database:get('bot:text:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Text has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الدردشه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
end
         database:set('bot:text:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> Text is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, 0, 1,'`📌¦`_ الدردشه بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "text ban" or TSHAKE[2] == "الدردشه بالطرد" then
	  if not database:get('bot:text:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Text ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الدردشه بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
end
         database:set('bot:text:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> Text ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الدردشه بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "text warn" or TSHAKE[2] == "الدردشه بالتحذير" then
	  if not database:get('bot:text:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Text ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الدردشه بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..'  ♩', 1, 'md')
end
         database:set('bot:text:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> Text warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الدردشه بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "inline" or TSHAKE[2] == "الانلاين" then
	  if not database:get('bot:inline:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> inline has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الانلاين _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:inline:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> inline is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الانلاين بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "inline ban" or TSHAKE[2] == "الانلاين بالطرد" then
	  if not database:get('bot:inline:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> inline ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الانلاين بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:inline:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> inline ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, 0, 1,'`📌¦`_ الانلاين بالطرد بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "inline warn" or TSHAKE[2] == "الانلاين بالتحذير" then
	  if not database:get('bot:inline:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> inline ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الانلاين بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:inline:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> inline warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الانلاين بالتحذير بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "photo" or TSHAKE[2] == "الصور" then
	  if not database:get('bot:photo:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> photo has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الصور _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:photo:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> photo is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصور بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "photo ban" or TSHAKE[2] == "الصور بالطرد" then
	  if not database:get('bot:photo:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> photo ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الصور بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:photo:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> photo ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصور بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "photo warn" or TSHAKE[2] == "الصور بالتحذير" then
	  if not database:get('bot:photo:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> photo ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الصور بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:photo:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> photo warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصور بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "video" or TSHAKE[2] == "الفيديو" then
	  if not database:get('bot:video:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> video has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الفيديو _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:video:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> video is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الفيديو بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "video ban" or TSHAKE[2] == "الفيديو بالطرد" then
	  if not database:get('bot:video:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Text ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الفيديو بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:video:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> video ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الفيديو بالطرد بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "video warn" or TSHAKE[2] == "الفيديو بالتحذير" then
	  if not database:get('bot:video:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> video ban has been_ *Locked*', 1, 'md')
      else
 send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الفيديو بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md') 
end
         database:set('bot:video:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> video warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصوت بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "gif" or TSHAKE[2] == "المتحركه" then
	  if not database:get('bot:gifs:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> gifs has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل المتحركه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:gifs:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> gifs is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المتحركه بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "gif ban" or TSHAKE[2] == "المتحركه بالطرد" then
	  if not database:get('bot:gifs:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> gifs ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل المتحركه بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:gifs:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> gifs ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المتحركه بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "gif warn" or TSHAKE[2] == "المتحركه بالتحذير" then
	  if not database:get('bot:gifs:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> gifs ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل المتحركه بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:gifs:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> gifs warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المتحركه بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "music" or TSHAKE[2] == "الاغاني" then
	  if not database:get('bot:music:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> music has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الاغاني _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:music:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> music is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الاغاني بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')      end
      end
      end
      if mutept[2] == "music ban" or TSHAKE[2] == "الاغاني بالطرد" then
	  if not database:get('bot:music:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> music ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الاغاني بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:music:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> music ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الاغاني بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "music warn" or TSHAKE[2] == "الاغاني بالتحذير" then
	  if not database:get('bot:music:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Text ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الاغاني بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:music:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> Text warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الاغاني بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "voice" or TSHAKE[2] == "الصوت" then
	  if not database:get('bot:voice:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> voice has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الصوت _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:voice:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> voice is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصوت بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "voice ban" or TSHAKE[2] == "الصوت بالطرد" then
	  if not database:get('bot:voice:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> voice ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الصوت بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:voice:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> voice ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصوت بالطرد بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "voice warn" or TSHAKE[2] == "الصوت بالتحذير" then
	  if not database:get('bot:voice:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> voice ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الصوت بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:voice:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> voice warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصوت بالتحذير بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "links" or TSHAKE[2] == "الروابط" then
	  if not database:get('bot:links:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> links has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الروابط _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:links:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> links is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الروابط بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "links ban" or TSHAKE[2] == "الروابط بالطرد" then
	  if not database:get('bot:links:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> links ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الروابط بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:links:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> links ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الروابط بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "links warn" or TSHAKE[2] == "الروابط بالتحذير" then
	  if not database:get('bot:links:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> links ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الروابط بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:links:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> links warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الروابط بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "location" or TSHAKE[2] == "الشبكات" then
	  if not database:get('bot:location:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> location has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الشبكات _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:location:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> location is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الشبكات بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`��¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "location ban" or TSHAKE[2] == "الشبكات بالطرد" then
	  if not database:get('bot:location:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> location ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الشبكات بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:location:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> location ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الشبكات بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "location warn" or TSHAKE[2] == "الشبكات بالتحذير" then
	  if not database:get('bot:location:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> location ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الشبكات بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:location:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> location warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الشبكات يالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "tag" or TSHAKE[2] == "المعرف" then
	  if not database:get('bot:tag:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> tag has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل المعرف _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:tag:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> tag is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المعرف بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "tag ban" or TSHAKE[2] == "المعرف بالطرد" then
	  if not database:get('bot:tag:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> tag ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل المعرف بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:tag:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> tag ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المعرف بالطرد بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "tag warn" or TSHAKE[2] == "المعرف بالتحذير" then
	  if not database:get('bot:tag:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> tag ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل المعرف بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:tag:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> tag warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المعرف بالتحذير بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "hashtag" or TSHAKE[2] == "التاك" then
	  if not database:get('bot:hashtag:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> hashtag has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل التاك _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:hashtag:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> hashtag is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ التاك بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "hashtag ban" or TSHAKE[2] == "التاك بالطرد" then
	  if not database:get('bot:hashtag:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> hashtag ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل التاك بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:hashtag:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> hashtag ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ التاك بالطرد بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "hashtag warn" or TSHAKE[2] == "التاك بالتحذير" then
	  if not database:get('bot:hashtag:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> hashtag ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل التاك بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:hashtag:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> hashtag warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ التاك بالتحذير بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "contact" or TSHAKE[2] == "الجهات" then
	  if not database:get('bot:contact:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> contact has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل جهات الاتصال _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:contact:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> contact is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ جهات الاتصال بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "contact ban" or TSHAKE[2] == "الجهات بالطرد" then
	  if not database:get('bot:contact:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> contact ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل جهات الاتصال بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:contact:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> contact ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ جهات الاتصال بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "contact warn" or TSHAKE[2] == "الجهات بالتحذير" then
	  if not database:get('bot:contact:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> contact ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل جهات الاتصال بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:contact:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> contact warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ جهات الاتصال بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "webpage" or TSHAKE[2] == "المواقع" then
	  if not database:get('bot:webpage:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> webpage has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل المواقع _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:webpage:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> webpage is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_المواقع بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "webpage ban" or TSHAKE[2] == "المواقع بالطرد" then
	  if not database:get('bot:webpage:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> webpage ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل المواقع بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:webpage:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> webpage ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المواقع بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "webpage warn" or TSHAKE[2] == "المواقع بالتحذير" then
	  if not database:get('bot:webpage:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> webpage ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل المواقع بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:webpage:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> webpage warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المواقع بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "arabic" or TSHAKE[2] == "العربيه" then
	  if not database:get('bot:arabic:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> arabic has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل العربيه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:arabic:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> arabic is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ العربيه بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "arabic ban" or TSHAKE[2] == "العربيه بالطرد" then
	  if not database:get('bot:arabic:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> arabic ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل العربيه بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:arabic:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> arabic ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ العربيه بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "arabic warn" or TSHAKE[2] == "العربيه بالتحذير" then
	  if not database:get('bot:arabic:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> arabic ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل العربيه بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:arabic:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> arabic warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ العربيه بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "english" or TSHAKE[2] == "الانكليزيه" then
	  if not database:get('bot:english:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> english has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الانكليزيه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:english:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> english is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الانكليزيه بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "english ban" or TSHAKE[2] == "الانكليزيه بالطرد" then
	  if not database:get('bot:text:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> english ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الانكليزيه بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:english:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> english ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الانكليزيه بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "english warn" or TSHAKE[2] == "الانكليزيه بالتحذير" then
	  if not database:get('bot:english:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> english ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الانكليزيه بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:english:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> english warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الانكليزيه بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "spam del" or TSHAKE[2] == "الكلايش" then
	  if not database:get('bot:spam:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> spam has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الكلايش _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:spam:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> spam is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الكلايش بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "spam warn" or TSHAKE[2] == "الكلايش بالتحذير" then
	  if not database:get('bot:spam:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> spam ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الكلايش بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:spam:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> spam warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الكلايش بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "sticker" or TSHAKE[2] == "الملصقات" then
	  if not database:get('bot:sticker:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> sticker has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الملصقات _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:sticker:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> sticker is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الملصقات بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "sticker ban" or TSHAKE[2] == "الملصقات بالطرد" then
	  if not database:get('bot:sticker:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> sticker ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الملصقات بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:sticker:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> sticker ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الملصقات بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "sticker warn" or TSHAKE[2] == "الملصقات بالتحذير" then
	  if not database:get('bot:sticker:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> sticker ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الملصقات بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:sticker:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> sticker warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الملصقات بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
	  if mutept[2] == "service" or TSHAKE[2] == "الدخول بالرابط" then
	  if not database:get('bot:tgservice:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> tgservice has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الدخول بالرابط _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:tgservice:mute'..msg.chat_id_,true)
       else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> tgservice is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الدخول بالرابط بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "fwd" or TSHAKE[2] == "التوجيه" then
	  if not database:get('bot:forward:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> forward has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل التوجيه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:forward:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> forward is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ التوجيه بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "fwd ban" or TSHAKE[2] == "التوجيه بالطرد" then
	  if not database:get('bot:forward:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> forward ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل التوجيه بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:forward:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> forward ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ التوجيه بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "fwd warn" or TSHAKE[2] == "التوجيه بالتحذير" then
	  if not database:get('bot:forward:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> forward ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل التوجيه بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:forward:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> forward warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ التوجيه بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "cmd" or TSHAKE[2] == "الشارحه" then
	  if not database:get('bot:cmd:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> cmd has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الشارحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:cmd:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> cmd is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الشارحه بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "cmd ban" or TSHAKE[2] == "الشارحه بالطرد" then
	  if not database:get('bot:cmd:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> cmd ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الشارحه بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:cmd:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> cmd ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الشارحه بالطرد بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`��¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
    end
    
    if mutept[2] == "file" or TSHAKE[2] == "الملفات" then
	  if not database:get('bot:document:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> file has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الملفات _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:set('bot:document:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> file is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_الملفات بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "file ban" or TSHAKE[2] == "الملفات بالطرد" then
	  if not database:get('bot:document:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> file ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الملفات بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:document:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> file ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الملفات بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "file warn" or TSHAKE[2] == "الملفات بالتحذير" then
	  if not database:get('bot:document:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> file ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الملفات بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:document:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> file warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الملفات بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
  end
  
      if mutept[2] == "markdown" or TSHAKE[2] == "الماركدون" then
	  if not database:get('bot:markdown:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> markdown has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الماركدون _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:markdown:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> markdown is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_الماركدون بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if mutept[2] == "markdown ban" or TSHAKE[2] == "الماركدون بالطرد" then
	  if not database:get('bot:markdown:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> markdown ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الماركدون بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:markdown:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> markdown ban is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الماركدون بالطرد بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if mutept[2] == "markdown warn" or TSHAKE[2] == "الماركدون بالتحذير" then
	  if not database:get('bot:markdown:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> markdown ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الماركدون بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:markdown:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> markdown warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الماركدون بالتحذير بالفعل مقفوله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
    end
    
      if mutept[2] == "cmd warn" or TSHAKE[2] == "الشارحه بالتحذير" then
	  if not database:get('bot:cmd:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> cmd ban has been_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم قفل الشارحه بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:set('bot:cmd:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> cmd warn is already_ *Locked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الشارحه بالتحذير بالفعل مقفول _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
	end 
	-----------------------------------------------------------------------------------------------
  	if text:match("^[Uu][Nn][Ll][Oo][Cc][Kk] (.*)$") or text:match("^فتح (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local unmutept = {string.match(text, "^([Uu][Nn][Ll][Oo][Cc][Kk]) (.*)$")} 
	local UNTSHAKE = {string.match(text, "^(فتح) (.*)$")} 
      if unmutept[2] == "all" or UNTSHAKE[2] == "الكل" then
	  if database:get('bot:muteall'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> mute all has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الوسائط _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:muteall'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_> mute all is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الوسائط بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`��¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "all warn" or UNTSHAKE[2] == "الكل بالتحذير" then
	  if database:get('bot:muteallwarn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> mute all warn has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الوسائط بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:muteallwarn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> mute all warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الوسائط بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "all ban" or UNTSHAKE[2] == "الكل بالطرد" then
	  if database:get('bot:muteallban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> mute all ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الوسائط بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:muteallban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> mute all ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الوسائط بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "text" or UNTSHAKE[2] == "الدردشه" then
	  if database:get('bot:text:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Text has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الدردشه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:text:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> Text is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الدردشه بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "text ban" or UNTSHAKE[2] == "الدردشه بالطرد" then
	  if database:get('bot:text:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Text ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الدردشه بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:text:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> Text ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الدردشه بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "text warn" or UNTSHAKE[2] == "الدردشه بالتحذير" then
	  if database:get('bot:text:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Text ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الدردشه بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:text:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> Text warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الدردشه بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "inline" or UNTSHAKE[2] == "الانلاين" then
	  if database:get('bot:inline:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> inline has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الانلاين _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:inline:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> inline is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الانلاين بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "inline ban" or UNTSHAKE[2] == "الانلاين بالطرد" then
	  if database:get('bot:inline:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> inline ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الانلاين بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:inline:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> inline ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الانلاين بالطرد بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "inline warn" or UNTSHAKE[2] == "الانلاين بالتحذير" then
	  if database:get('bot:inline:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> inline ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الانلاين بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:inline:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> inline warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الانلاين بالتحذير بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "photo" or UNTSHAKE[2] == "الصور" then
	  if database:get('bot:photo:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> photo has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الصور _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:photo:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> photo is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصور بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "photo ban" or UNTSHAKE[2] == "الصور بالطرد" then
	  if database:get('bot:photo:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> photo ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الصور بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:photo:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> photo ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصور بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "photo warn" or UNTSHAKE[2] == "الصور بالتحذير" then
	  if database:get('bot:photo:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> photo ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الصور بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:photo:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> photo warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصور بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "video" or UNTSHAKE[2] == "الفيديو" then
	  if database:get('bot:video:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> video has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الفيديو _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:video:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> video is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الفيديو بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "video ban" or UNTSHAKE[2] == "الفيديو بالطرد" then
	  if database:get('bot:video:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Text ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الفيديو بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:video:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> video ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الفيديو بالطرد بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "video warn" or UNTSHAKE[2] == "الفيديو بالتحذير" then
	  if database:get('bot:video:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> video ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الفيديو بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:video:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> video warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الفيديو بالتحذير بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "gif" or UNTSHAKE[2] == "المتحركه" then
	  if database:get('bot:gifs:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> gifs has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح المتحركه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:gifs:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> gifs is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المتحركه بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "gif ban" or UNTSHAKE[2] == "المتحركه بالطرد" then
	  if database:get('bot:gifs:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> gifs ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح المتحركه بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:gifs:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> gifs ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المتحركه بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "gif warn" or UNTSHAKE[2] == "المتحركه بالتحذير" then
	  if database:get('bot:gifs:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> gifs ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح المتحركه بالتحذير _'..'\n'..'`📌����` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:gifs:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> gifs warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المتحركه بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "music" or UNTSHAKE[2] == "الاغاني" then
	  if database:get('bot:music:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> music has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الاغاني _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:music:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> music is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الاغاني بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "music ban" or UNTSHAKE[2] == "الاغاني بالطرد" then
	  if database:get('bot:music:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> music ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الاغاني بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:music:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> music ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الاغاني بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "music warn" or UNTSHAKE[2] == "الاغاني بالتحذير" then
	  if database:get('bot:music:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Text ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الاغاني بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:music:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> Text warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الاغاني بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "voice" or UNTSHAKE[2] == "الصوت" then
	  if database:get('bot:voice:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> voice has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الصوت _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:voice:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> voice is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصوت بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "voice ban" or UNTSHAKE[2] == "الصوت بالطرد" then
	  if database:get('bot:voice:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> voice ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الصوت بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:voice:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> voice ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصوت بالطرد بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "voice warn" or UNTSHAKE[2] == "الصوت بالتحذير" then
	  if database:get('bot:voice:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> voice ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الصوت بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:voice:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> voice warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الصوت بالتحذير بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "links" or UNTSHAKE[2] == "الروابط" then
	  if database:get('bot:links:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> links has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الروابط _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:links:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> links is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الروابط بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "links ban" or UNTSHAKE[2] == "الروابط بالطرد" then
	  if database:get('bot:links:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> links ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الروابط بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:links:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> links ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الروابط بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "links warn" or UNTSHAKE[2] == "الروابط بالتحذير" then
	  if database:get('bot:links:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> links ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الروابط بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:links:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> links warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الروابط بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "location" or UNTSHAKE[2] == "الشبكات" then
	  if database:get('bot:location:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> location has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الشبكات _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:location:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> location is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الشبكات بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "location ban" or UNTSHAKE[2] == "الشبكات بالطرد" then
	  if database:get('bot:location:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> location ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الشبكات بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:location:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> location ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الشبكات بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "location warn" or UNTSHAKE[2] == "الشبكات بالتحذير" then
	  if database:get('bot:location:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> location ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الشبكات بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:location:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> location warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الشبكات بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
    end
    
    if unmutept[2] == "file" or UNTSHAKE[2] == "الملفات" then
	  if database:get('bot:document:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> file has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '● - `تم `✔️ `فتح الملفات `🔓\n\n● - `خاصية : المسح `⚠️', 1, 'md')
      end
         database:del('bot:document:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> file is already_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '● - `بالفعل تم` ✔️ `فتح الملفات` 🔓\n\n● - `خاصية : المسح` ⚠️', 1, 'md')
      end
      end
      end
      if unmutept[2] == "file ban" or UNTSHAKE[2] == "الملفات بالطرد" then
	  if database:get('bot:document:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> file ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '● - `تم `✔️ `فتح الملفات `🔓\n\n● - `خاصية : الطرد `⚠️', 1, 'md')
      end
         database:del('bot:document:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> file ban is already_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '● - `بالفعل تم` ✔️ `فتح الملفات` 🔓\n\n● - `خاصية : الطرد` ⚠️', 1, 'md')
      end
      end
      end
      if unmutept[2] == "file warn" or UNTSHAKE[2] == "الملفات بالتحذير" then
	  if database:get('bot:document:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> file ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '● - `تم `✔️ `فتح الملفات `🔓\n\n● - `خاصية : التحذير `⚠️', 1, 'md')
      end
         database:del('bot:document:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> file warn is already_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '● - `بالفعل تم` ✔️ `فتح الملفات` 🔓\n\n● - `خاصية : التحذير` ⚠️', 1, 'md')
      end
      end
      end    

      if unmutept[2] == "markdown" or UNTSHAKE[2] == "الماركدون" then
	  if database:get('bot:markdown:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> markdown has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الماركدون بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:del('bot:markdown:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> markdown is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_الماركدون بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "markdown ban" or UNTSHAKE[2] == "الماركدون بالطرد" then
	  if database:get('bot:markdown:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> markdown ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الماركدون بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:markdown:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> markdown ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الماركدون بالطرد بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if unmutept[2] == "markdown warn" or UNTSHAKE[2] == "الماركدون بالتحذير" then
	  if database:get('bot:markdown:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> markdown ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الماركدون بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:markdown:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> markdown warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الماركدون بالتحذير بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end    
    
      if unmutept[2] == "tag" or UNTSHAKE[2] == "المعرف" then
	  if database:get('bot:tag:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> tag has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح المعرف _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:tag:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> tag is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المعرف بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "tag ban" or UNTSHAKE[2] == "المعرف بالطرد" then
	  if database:get('bot:tag:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> tag ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح المعرف بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:tag:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> tag ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`��¦`_ المعرف بالطرد بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "tag warn" or UNTSHAKE[2] == "المعرف بالتحذير" then
	  if database:get('bot:tag:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> tag ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح المعرف بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:tag:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> tag warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المعرف بالتحذير بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "hashtag" or UNTSHAKE[2] == "التاك" then
	  if database:get('bot:hashtag:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> hashtag has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح التاك _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:hashtag:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> hashtag is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ التاك بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "hashtag ban" or UNTSHAKE[2] == "التاك بالطرد" then
	  if database:get('bot:hashtag:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> hashtag ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح التاك بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:hashtag:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> hashtag ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ التاك بالطرد بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "hashtag warn" or UNTSHAKE[2] == "التاك بالتحذير" then
	  if database:get('bot:hashtag:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> hashtag ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح التاك بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:del('bot:hashtag:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> hashtag warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ التاك بالتحذير بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "contact" or UNTSHAKE[2] == "الجهات" then
	  if database:get('bot:contact:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> contact has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح جهات الاتصال _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:contact:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> contact is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ جهات الاتصال بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "contact ban" or UNTSHAKE[2] == "الجهات بالطرد" then
	  if database:get('bot:contact:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> contact ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح جهات الاتصال بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:contact:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> contact ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ جهات الاتصال بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "contact warn" or UNTSHAKE[2] == "الجهات بالتحذير" then
	  if database:get('bot:contact:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> contact ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح جهات الاتصال بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:contact:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> contact warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ جهات الاتصال يالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "webpage" or UNTSHAKE[2] == "المواقع" then
	  if database:get('bot:webpage:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> webpage has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح المواقع _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:webpage:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> webpage is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المواقع بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "webpage ban" or UNTSHAKE[2] == "المواقع بالطرد" then
	  if database:get('bot:webpage:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> webpage ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح المواقع بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:webpage:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> webpage ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المواقع بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "webpage warn" or UNTSHAKE[2] == "المواقع بالتحذير" then
	  if database:get('bot:webpage:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> webpage ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح المواقع بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:webpage:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> webpage warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ المواقع بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "arabic" or UNTSHAKE[2] == "العربيه" then
	  if database:get('bot:arabic:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> arabic has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح العربيه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:arabic:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> arabic is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ العربيه بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "arabic ban" or UNTSHAKE[2] == "العربيه بالطرد" then
	  if database:get('bot:arabic:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> arabic ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح العربيه بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:arabic:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> arabic ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ العربيه بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "arabic warn" or UNTSHAKE[2] == "العربيه بالتحذير" then
	  if database:get('bot:arabic:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> arabic ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح العربيه بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:arabic:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> arabic warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ العربيه بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "english" or UNTSHAKE[2] == "الانكليزيه" then
	  if database:get('bot:english:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> english has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الانكليزيه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:english:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> english is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الانكليزيه بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "english ban" or UNTSHAKE[2] == "الانكليزيه بالطرد" then
	  if database:get('bot:text:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> english ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الانكليزيه بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:english:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> english ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الانكليزيه بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "english warn" or UNTSHAKE[2] == "الانكليزيه بالتحذير" then
	  if database:get('bot:english:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> english ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الانكليزيه بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:english:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> english warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الانكليزيه بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "spam del" or UNTSHAKE[2] == "الكلايش" then
	  if database:get('bot:spam:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> spam has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الكلايش _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:spam:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> spam is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الكلايش بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "spam warn" or UNTSHAKE[2] == "الكلايش بالتحذير" then
	  if database:get('bot:spam:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> spam ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الكلايش بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:spam:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> spam warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الكلايش بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "sticker" or UNTSHAKE[2] == "الملصقات" then
	  if database:get('bot:sticker:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> sticker has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الملصقات _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:sticker:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> sticker is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الملصقات بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "sticker ban" or UNTSHAKE[2] == "الملصقات بالطرد" then
	  if database:get('bot:sticker:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> sticker ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الملصقات بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:sticker:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> sticker ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الملصقات بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "sticker warn" or UNTSHAKE[2] == "الملصقات بالتحذير" then
	  if database:get('bot:sticker:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> sticker ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الملصقات بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:sticker:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> sticker warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الملصقات بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
	  if unmutept[2] == "service" or UNTSHAKE[2] == "الدخول بالرابط" then
	  if database:get('bot:tgservice:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> tgservice has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الدخول بالرابط بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:tgservice:mute'..msg.chat_id_)
       else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> tgservice is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الدخول بالرابط بالتحذير بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`��¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
      end
      end
      if unmutept[2] == "fwd" or UNTSHAKE[2] == "التوجيه" then
	  if database:get('bot:forward:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> forward has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح التوجيه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
         database:del('bot:forward:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> forward is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ التوجيه بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "fwd ban" or UNTSHAKE[2] == "التوجيه بالطرد" then
	  if database:get('bot:forward:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> forward ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح التوجيه بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:forward:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> forward ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ التوجيه بالطرد بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "fwd warn" or UNTSHAKE[2] == "التوجيه بالتحذير" then
	  if database:get('bot:forward:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> forward ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح التوجيه بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:forward:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> forward warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ التوجيه بالتحذير بالفعل مفتوح _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "cmd" or UNTSHAKE[2] == "الشارحه" then
	  if database:get('bot:cmd:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> cmd has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الشارحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:cmd:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> cmd is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الشارحه بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "cmd ban" or UNTSHAKE[2] == "الشارحه بالطرد" then
	  if database:get('bot:cmd:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> cmd ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الشارحه بالطرد _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:cmd:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> cmd ban is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الشارحه بالطرد بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
      if unmutept[2] == "cmd warn" or UNTSHAKE[2] == "الشارحه بالتحذير" then
	  if database:get('bot:cmd:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> cmd ban has been_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ تم فتح الشارحه بالتحذير _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
         database:del('bot:cmd:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> cmd warn is already_ *unLocked*', 1, 'md')
      else
send(msg.chat_id_, 0, 1,'`📌¦`_ الشارحه بالتحذير بالفعل مفتوحه _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
      end
      end
	end 
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('تعديل','edit')
  	if text:match("^[Ee][Dd][Ii][Tt] (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local editmsg = {string.match(text, "^([Ee][Dd][Ii][Tt]) (.*)$")} 
		 edit(msg.chat_id_, msg.reply_to_message_id_, nil, editmsg[2], 1, 'html')
    if database:get('lang:gp:'..msg.chat_id_) then
		 	          send(msg.chat_id_, msg.id_, 1, '*Done* _Edit My Msg_', 1, 'md')
else 
		 	          send(msg.chat_id_, msg.id_, 1, '`📌¦` _تم تعديل الرساله_', 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
    if text:match("^[Cc][Ll][Ee][Aa][Nn] [Gg][Bb][Aa][Nn][Ll][Ii][Ss][Tt]$") or text:match("^مسح قائمه العام$") and is_sudo(msg) then
    if database:get('lang:gp:'..msg.chat_id_) then
      text = '_> Banall has been_ *Cleaned*'
    else 
      text = '`📌¦ `_تم مسح قائمه العام_'
end
      database:del('bot:gbanned:')
	    send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
  end

    if text:match("^[Cc][Ll][Ee][Aa][Nn] [Aa][Dd][Mm][Ii][Nn][Ss]$") or text:match("^مسح ادمنيه البوت$") and is_sudo(msg) then
    if database:get('lang:gp:'..msg.chat_id_) then
      text = '_> adminlist has been_ *Cleaned*'
    else 
text = '`📌¦ `_تم مسح قائمه ادمنيه البوت_'
end
      database:del('bot:admins:')
	    send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
  end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('مسح','clean')
  	if text:match("^[Cc][Ll][Ee][Aa][Nn] (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local txt = {string.match(text, "^([Cc][Ll][Ee][Aa][Nn]) (.*)$")} 
       if txt[2] == 'banlist' or txt[2] == 'Banlist' or txt[2] == 'المحظورين' then
	      database:del('bot:banned:'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_> Banlist has been_ *Cleaned*', 1, 'md')
        else 
          send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم مسح قائمه المحظورين_', 1, 'md')
end
       end
	   if txt[2] == 'bots' or txt[2] == 'Bots' or txt[2] == 'البوتات' then
	  local function g_bots(extra,result,success)
      local bots = result.members_
      for i=0 , #bots do
          chat_kick(msg.chat_id_,bots[i].msg.sender_user_id_)
          end 
      end
    channel_get_bots(msg.chat_id_,g_bots) 
    if database:get('lang:gp:'..msg.chat_id_) then
	          send(msg.chat_id_, msg.id_, 1, '_> All bots_ *kicked!*', 1, 'md')
          else 
	          send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم طرد جميع البوتات_', 1, 'md')
end
	end
	   if txt[2] == 'modlist' or txt[2] == 'Modlist' or txt[2] == 'الادمنيه' and is_owner(msg.sender_user_id_, msg.chat_id_) then
	      database:del('bot:mods:'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_> Modlist has been_ *Cleaned*', 1, 'md')
      else 
          send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم مسح قائمه الادمنيه_', 1, 'md')
end
       end 
	   if txt[2] == 'owners' or txt[2] == 'Owners' or txt[2] == 'المدراء' and is_sudo(msg) then
	      database:del('bot:owners:'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_> ownerlist has been_ *Cleaned*', 1, 'md')
        else 
          send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم مسح قائمه المدراء_', 1, 'md')
end
       end
	   if txt[2] == 'rules' or txt[2] == 'Rules' or txt[2] == 'القوانين' then
	      database:del('bot:rules'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_> rules has been_ *Cleaned*', 1, 'md')
        else 
          send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم مسح القوانين المحفوظه_', 1, 'md')
end
       end
	   if txt[2] == 'link' or  txt[2] == 'Link' or  txt[2] == 'الرابط' then
	      database:del('bot:group:link'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_> link has been_ *Cleaned*', 1, 'md')
        else 
          send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم مسح الرابط المحفوظ_', 1, 'md')
end
       end
	   if txt[2] == 'badlist' or txt[2] == 'Badlist' or txt[2] == 'الكلمات الممنوعه' then
	      database:del('bot:filters:'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_> badlist has been_ *Cleaned*', 1, 'md')
        else 
          send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم مسح قائمه الكلمات الممنوعه_', 1, 'md')
end
       end
	   if txt[2] == 'silentlist' or txt[2] == 'Silentlist' or txt[2] == 'المكتومين' then
	      database:del('bot:muted:'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_> silentlist has been_ *Cleaned*', 1, 'md')
        else 
          send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم مسح قائمه المكتومين_', 1, 'md')
end
       end
       
    end 
	--➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖
  	 if text:match("^[Ss] [Dd][Ee][Ll]$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	if database:get('bot:muteall'..msg.chat_id_) then
	mute_all = '`lock | 🔐`'
	else
	mute_all = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:text:mute'..msg.chat_id_) then
	mute_text = '`lock | 🔐`'
	else
	mute_text = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:photo:mute'..msg.chat_id_) then
	mute_photo = '`lock | 🔐`'
	else
	mute_photo = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:video:mute'..msg.chat_id_) then
	mute_video = '`lock | 🔐`'
	else
	mute_video = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:gifs:mute'..msg.chat_id_) then
	mute_gifs = '`lock | 🔐`'
	else
	mute_gifs = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('anti-flood:'..msg.chat_id_) then
	mute_flood = '`unlock | 🔓`'
	else  
	mute_flood = '`lock | 🔐`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if not database:get('flood:max:'..msg.chat_id_) then
	flood_m = 10
	else
	flood_m = database:get('flood:max:'..msg.chat_id_)
end
--➖➖➖➖➖➖➖➖➖➖
	if not database:get('flood:time:'..msg.chat_id_) then
	flood_t = 2
	else
	flood_t = database:get('flood:time:'..msg.chat_id_)
	end
--➖➖➖➖➖➖➖➖���➖
	if database:get('bot:music:mute'..msg.chat_id_) then
	mute_music = '`lock | 🔐`'
	else
	mute_music = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:bots:mute'..msg.chat_id_) then
	mute_bots = '`lock | 🔐`'
	else
	mute_bots = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:inline:mute'..msg.chat_id_) then
	mute_in = '`lock | 🔐`'
	else
	mute_in = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:voice:mute'..msg.chat_id_) then
	mute_voice = '`lock | 🔐`'
	else
	mute_voice = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('editmsg'..msg.chat_id_) then
	mute_edit = '`lock | 🔐`'
	else
	mute_edit = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:links:mute'..msg.chat_id_) then
	mute_links = '`lock | 🔐`'
	else
	mute_links = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:pin:mute'..msg.chat_id_) then
	lock_pin = '`lock | 🔐`'
	else
	lock_pin = '`unlock | 🔓`'
	end 
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:sticker:mute'..msg.chat_id_) then
	lock_sticker = '`lock | 🔐`'
	else
	lock_sticker = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:tgservice:mute'..msg.chat_id_) then
	lock_tgservice = '`lock | 🔐`'
	else
	lock_tgservice = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:webpage:mute'..msg.chat_id_) then
	lock_wp = '`lock | 🔐`'
	else
	lock_wp = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:hashtag:mute'..msg.chat_id_) then
	lock_htag = '`lock | 🔐`'
	else
	lock_htag = '`unlock | 🔓`'
end
--➖➖➖➖➖➖➖➖➖➖
   if database:get('bot:cmd:mute'..msg.chat_id_) then
	lock_cmd = '`lock | 🔐`'
	else
	lock_cmd = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:tag:mute'..msg.chat_id_) then
	lock_tag = '`lock | 🔐`'
	else
	lock_tag = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:location:mute'..msg.chat_id_) then
	lock_location = '`lock | 🔐`'
	else
	lock_location = '`unlock | 🔓`'
end
--➖➖➖➖➖➖➖➖➖➖
if not database:get('bot:sens:spam'..msg.chat_id_) then
spam_c = 250
else
spam_c = database:get('bot:sens:spam'..msg.chat_id_)
end

if not database:get('bot:sens:spam:warn'..msg.chat_id_) then
spam_d = 250
else
spam_d = database:get('bot:sens:spam:warn'..msg.chat_id_)
end

--➖➖➖➖➖➖➖➖➖➖
  if database:get('bot:contact:mute'..msg.chat_id_) then
	lock_contact = '`lock | 🔐`'
	else
	lock_contact = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
  if database:get('bot:spam:mute'..msg.chat_id_) then
	mute_spam = '`lock | 🔐`'
	else
	mute_spam = '`unlock | 🔓`'
end

	if database:get('anti-flood:warn'..msg.chat_id_) then
	lock_flood = '`unlock | 🔓`'
	else 
	lock_flood = '`lock | 🔐`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:english:mute'..msg.chat_id_) then
	lock_english = '`lock | 🔐`'
	else
	lock_english = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:arabic:mute'..msg.chat_id_) then
	lock_arabic = '`lock | 🔐`'
	else
	lock_arabic = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:forward:mute'..msg.chat_id_) then
	lock_forward = '`lock | 🔐`'
	else
	lock_forward = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get("bot:welcome"..msg.chat_id_) then
	send_welcome = '`active | ✔`'
	else
	send_welcome = '`inactive | ⭕`'
end
		if not database:get('flood:max:warn'..msg.chat_id_) then
	flood_warn = 10
	else
	flood_warn = database:get('flood:max:warn'..msg.chat_id_)
end
--➖➖➖➖➖➖➖➖➖➖
	local ex = database:ttl("bot:charge:"..msg.chat_id_)
                if ex == -1 then
				exp_dat = '`NO Fanil`'
				else
				exp_dat = math.floor(ex / 86400) + 1
			    end
--➖➖➖➖➖➖➖➖➖➖
	 local TXT = "*Group Settings Del*\n➖➖➖➖➖➖➖➖➖➖\n*Del all* : "..mute_all.."\n" .."*Del Links* : "..mute_links.."\n" .."*Del Edit* : "..mute_edit.."\n" .."*Del Bots* : "..mute_bots.."\n" .."*Del Inline* : "..mute_in.."\n" .."*Del English* : "..lock_english.."\n" .."*Del Forward* : "..lock_forward.."\n" .."*Del Pin* : "..lock_pin.."\n" .."*Del Arabic* : "..lock_arabic.."\n" .."*Del Hashtag* : "..lock_htag.."\n".."*Del tag* : "..lock_tag.."\n" .."*Del Webpage* : "..lock_wp.."\n" .."*Del Location* : "..lock_location.."\n" .."*Del Tgservice* : "..lock_tgservice.."\n"
.."*Del Spam* : "..mute_spam.."\n" .."*Del Photo* : "..mute_photo.."\n" .."*Del Text* : "..mute_text.."\n" .."*Del Gifs* : "..mute_gifs.."\n" .."*Del Voice* : "..mute_voice.."\n" .."*Del Music* : "..mute_music.."\n" .."*Del Video* : "..mute_video.."\n*Del Cmd* : "..lock_cmd.."\n" .."*Flood Ban* : "..mute_flood.."\n" .."*Flood Mute* : "..lock_flood.."\n"
.."➖➖➖➖➖➖➖➖➖➖\n*Welcome* : "..send_welcome.."\n*Flood Time*  "..flood_t.."\n" .."*Flood Max* : "..flood_m.."\n" .."*Flood Mute* : "..flood_warn.."\n" .."*Number Spam* : "..spam_c.."\n" .."*Warn Spam* : "..spam_d.."\n"
.."*Expire* : "..exp_dat.."\n➖➖➖➖➖➖➖➖➖➖"
         send(msg.chat_id_, msg.id_, 1, TXT, 1, 'md')
    end

          local text = msg.content_.text_:gsub('اعدادات المسح','sdd1')
  	 if text:match("^[Ss][Dd][Dd]1$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	if database:get('bot:muteall'..msg.chat_id_) then
	mute_all = 'مفعل | 🔐'
	else
	mute_all = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:text:mute'..msg.chat_id_) then
	mute_text = 'مفعل | 🔐'
	else
	mute_text = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:photo:mute'..msg.chat_id_) then
	mute_photo = 'مفعل | 🔐'
	else
	mute_photo = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:video:mute'..msg.chat_id_) then
	mute_video = 'مفعل | 🔐'
	else
	mute_video = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:gifs:mute'..msg.chat_id_) then
	mute_gifs = 'مفعل | 🔐'
	else
	mute_gifs = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('anti-flood:'..msg.chat_id_) then
	mute_flood = 'معطل | 🔓'
	else  
	mute_flood = 'مفعل | 🔐'
	end
--➖➖➖➖➖➖➖➖➖➖
	if not database:get('flood:max:'..msg.chat_id_) then
	flood_m = 10
	else
	flood_m = database:get('flood:max:'..msg.chat_id_)
end
--➖➖➖➖➖➖➖➖➖➖
	if not database:get('flood:time:'..msg.chat_id_) then
	flood_t = 2
	else
	flood_t = database:get('flood:time:'..msg.chat_id_)
	end
	------------
	if database:get('bot:music:mute'..msg.chat_id_) then
	mute_music = 'مفعل | 🔐'
	else
	mute_music = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:bots:mute'..msg.chat_id_) then
	mute_bots = 'مفعل | 🔐'
	else
	mute_bots = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:inline:mute'..msg.chat_id_) then
	mute_in = 'مفعل | 🔐'
	else
	mute_in = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:voice:mute'..msg.chat_id_) then
	mute_voice = 'مفعل | 🔐'
	else
	mute_voice = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('editmsg'..msg.chat_id_) then
	mute_edit = 'مفعل | 🔐'
	else
	mute_edit = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:links:mute'..msg.chat_id_) then
	mute_links = 'مفعل | 🔐'
	else
	mute_links = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:pin:mute'..msg.chat_id_) then
	lock_pin = 'مفعل | 🔐'
	else
	lock_pin = 'معطل | 🔓'
	end 
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:sticker:mute'..msg.chat_id_) then
	lock_sticker = 'مفعل | 🔐'
	else
	lock_sticker = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:tgservice:mute'..msg.chat_id_) then
	lock_tgservice = 'مفعل | 🔐'
	else
	lock_tgservice = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:webpage:mute'..msg.chat_id_) then
	lock_wp = 'مفعل | 🔐'
	else
	lock_wp = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:hashtag:mute'..msg.chat_id_) then
	lock_htag = 'مفعل | 🔐'
	else
	lock_htag = 'معطل | 🔓'
end
--➖➖➖➖➖➖➖➖➖➖
   if database:get('bot:cmd:mute'..msg.chat_id_) then
	lock_cmd = 'مفعل | 🔐'
	else
	lock_cmd = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:tag:mute'..msg.chat_id_) then
	lock_tag = 'مفعل | 🔐'
	else
	lock_tag = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:location:mute'..msg.chat_id_) then
	lock_location = 'مفعل | 🔐'
	else
	lock_location = 'معطل | 🔓'
end
--➖➖➖➖➖➖➖➖➖➖
if not database:get('bot:sens:spam'..msg.chat_id_) then
spam_c = 250
else
spam_c = database:get('bot:sens:spam'..msg.chat_id_)
end

if not database:get('bot:sens:spam:warn'..msg.chat_id_) then
spam_d = 250
else
spam_d = database:get('bot:sens:spam:warn'..msg.chat_id_)
end
--➖➖➖➖➖➖➖➖➖➖
  if database:get('bot:contact:mute'..msg.chat_id_) then
	lock_contact = 'مفعل | 🔐'
	else
	lock_contact = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
  if database:get('bot:spam:mute'..msg.chat_id_) then
	mute_spam = 'مفعل | 🔐'
	else
	mute_spam = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:english:mute'..msg.chat_id_) then
	lock_english = 'مفعل | 🔐'
	else
	lock_english = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:arabic:mute'..msg.chat_id_) then
	lock_arabic = 'مفعل | 🔐'
	else
	lock_arabic = 'معطل | 🔓'
end

	if database:get('anti-flood:warn'..msg.chat_id_) then
	lock_flood = 'معطل | 🔓'
	else 
	lock_flood = 'مفعل | 🔐'
	end
--➖➖➖➖➖➖➖➖➖���
    if database:get('bot:forward:mute'..msg.chat_id_) then
	lock_forward = 'مفعل | 🔐'
	else
	lock_forward = 'معطل | ����'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get("bot:welcome"..msg.chat_id_) then
	send_welcome = 'مفعل | ✔'
	else
	send_welcome = 'معطل | ���'
end
		if not database:get('flood:max:warn'..msg.chat_id_) then
	flood_warn = 10
	else
	flood_warn = database:get('flood:max:warn'..msg.chat_id_)
end
--➖➖➖➖➖➖➖➖➖➖
	local ex = database:ttl("bot:charge:"..msg.chat_id_)
                if ex == -1 then
				exp_dat =  'لا نهائي '
				else
				exp_dat = math.floor(ex / 86400) + 1
			    end
 	------------
local TXT = "`📌¦ `_اعدادات المجموعه بالمسح_ \n➖➖➖➖➖➖➖➖➖➖➖\n`📌¦ `_كل الوسائط_ : "..mute_all.."\n" .."`📌¦ `_الروابط_ : "..mute_links.."\n" .."`📌¦ `_التعديل_ : "..mute_edit.."\n" .."`📌¦ `_البوتات_ : "..mute_bots.."\n" .."`📌¦ `_الانلاين_ : "..mute_in.."\n" .."`📌¦ `_اللغه الانكليزيه_ : "..lock_english.."\n" .."`📌¦ `_اعاده توجيه_ : "..lock_forward.."\n" .."`📌¦ `_التثبيت_ : "..lock_pin.."\n" .."`📌¦ `_اللغه العربيه_ : "..lock_arabic.."\n" .."`📌¦ `_التاك_ : "..lock_htag.."\n".."`📌¦ `_المعرف_ : "..lock_tag.."\n\n" .."`📌¦ `_المواقع_ : "..lock_wp.."\n" .."`📌¦ `_الشبكات_ : "..lock_location.."\n" .."`📌¦ `_الدخول بالرابط_ : "..lock_tgservice.."\n"
.."`📌¦ `_الكلايش_ : "..mute_spam.."\n" .."`📌¦ `_الصور_ : "..mute_photo.."\n" .."`📌¦ `_الدردشه_ : "..mute_text.."\n" .."`📌¦ `_المتحركه_ : "..mute_gifs.."\n" .."`📌¦ `_الصوت_ : "..mute_voice.."\n" .."`📌¦ `_الاغاني_ : "..mute_music.."\n" .."`📌¦ `_الفيديو_ : "..mute_video.."\n`📌¦ `_الشارحه_ : "..lock_cmd.."\n" .."`📌¦ `_التكرار بالطرد_ : "..mute_flood.."\n" .."`📌¦ `_التكرار بالكتم_ : "..lock_flood.."\n\n"
.."➖➖➖➖➖➖➖➖➖➖➖\n`📌¦ `_الترحيب_ : "..send_welcome.."\n`📌¦`_زمن التكرار_ : "..flood_t.."\n" .."`📌¦ `_عدد التكرار بالطرد_ : "..flood_m.."\n" .."`📌¦ `_عدد التكرار بالكتم_ : "..flood_warn.."\n\n" .."`📌¦ `_عدد الكلايش بالمسح_ : "..spam_c.."\n" .."`📌¦ `_عدد الكلايش بالتحذير_ : "..spam_d.."\n"
.."`📌¦ `_انقضاء البوت_ : "..exp_dat.."\n➖➖➖➖➖➖➖➖➖➖➖"
         send(msg.chat_id_, msg.id_, 1, TXT, 1, 'md')
    end
    
  	 if text:match("^[Ss] [Ww][Aa][Rr][Nn]$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	if database:get('bot:muteallwarn'..msg.chat_id_) then
	mute_all = '`lock | 🔐`'
	else
	mute_all = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:text:warn'..msg.chat_id_) then
	mute_text = '`lock | 🔐`'
	else
	mute_text = '`unlock | 🔓`'
end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:photo:warn'..msg.chat_id_) then
	mute_photo = '`lock | 🔐`'
	else
	mute_photo = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:video:warn'..msg.chat_id_) then
	mute_video = '`lock | 🔐`'
	else
	mute_video = '`unlock | 🔓`'
end

	if database:get('bot:spam:warn'..msg.chat_id_) then
	mute_spam = '`lock | 🔐`'
	else
	mute_spam = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:gifs:warn'..msg.chat_id_) then
	mute_gifs = '`lock | 🔐`'
	else
	mute_gifs = '`unlock | 🔓`'
end

--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:music:warn'..msg.chat_id_) then
	mute_music = '`lock | 🔐`'
	else
	mute_music = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:inline:warn'..msg.chat_id_) then
	mute_in = '`lock | 🔐`'
	else
	mute_in = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:voice:warn'..msg.chat_id_) then
	mute_voice = '`lock | 🔐`'
	else
	mute_voice = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:links:warn'..msg.chat_id_) then
	mute_links = '`lock | 🔐`'
	else
	mute_links = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:sticker:warn'..msg.chat_id_) then
	lock_sticker = '`lock | 🔐`'
	else
	lock_sticker = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
   if database:get('bot:cmd:warn'..msg.chat_id_) then
	lock_cmd = '`lock | 🔐`'
	else
	lock_cmd = '`unlock | 🔓`'
end

    if database:get('bot:webpage:warn'..msg.chat_id_) then
	lock_wp = '`lock | 🔐`'
	else
	lock_wp = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:hashtag:warn'..msg.chat_id_) then
	lock_htag = '`lock | 🔐`'
	else
	lock_htag = '`unlock | 🔓`'
end
	if database:get('bot:pin:warn'..msg.chat_id_) then
	lock_pin = '`lock | 🔐`'
	else
	lock_pin = '`unlock | 🔓`'
	end 
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:tag:warn'..msg.chat_id_) then
	lock_tag = '`lock | 🔐`'
	else
	lock_tag = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:location:warn'..msg.chat_id_) then
	lock_location = '`lock | 🔐`'
	else
	lock_location = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:contact:warn'..msg.chat_id_) then
	lock_contact = '`lock | 🔐`'
	else
	lock_contact = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
	
    if database:get('bot:english:warn'..msg.chat_id_) then
	lock_english = '`lock | 🔐`'
	else
	lock_english = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:arabic:warn'..msg.chat_id_) then
	lock_arabic = '`lock | 🔐`'
	else
	lock_arabic = '`unlock | 🔓`'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:forward:warn'..msg.chat_id_) then
	lock_forward = '`lock | 🔐`'
	else
	lock_forward = '`unlock | 🔓`'
end
--➖➖➖➖➖➖➖➖➖➖
--➖➖➖➖➖➖➖➖➖➖
	local ex = database:ttl("bot:charge:"..msg.chat_id_)
                if ex == -1 then
				exp_dat = '`NO Fanil`'
				else
				exp_dat = math.floor(ex / 86400) + 1
			    end
--➖➖➖➖➖➖➖➖➖➖
	 local TXT = "*Group Settings Warn*\n======================\n*Warn all* : "..mute_all.."\n" .."*Warn Links* : "..mute_links.."\n" .."*Warn Inline* : "..mute_in.."\n" .."*Warn Pin* : "..lock_pin.."\n" .."*Warn English* : "..lock_english.."\n" .."*Warn Forward* : "..lock_forward.."\n" .."*Warn Arabic* : "..lock_arabic.."\n" .."*Warn Hashtag* : "..lock_htag.."\n".."*Warn tag* : "..lock_tag.."\n" .."*Warn Webpag* : "..lock_wp.."\n" .."*Warn Location* : "..lock_location.."\n"
.."*Warn Spam* : "..mute_spam.."\n" .."*Warn Photo* : "..mute_photo.."\n" .."*Warn Text* : "..mute_text.."\n" .."*Warn Gifs* : "..mute_gifs.."\n" .."*Warn Voice* : "..mute_voice.."\n" .."*Warn Music* : "..mute_music.."\n" .."*Warn Video* : "..mute_video.."\n*Warn Cmd* : "..lock_cmd.."\n"
.."*Expire* : "..exp_dat.."\n======================"
         send(msg.chat_id_, msg.id_, 1, TXT, 1, 'md')
    end


          local text = msg.content_.text_:gsub('اعدادات التحذير','sdd2')
  	 if text:match("^[Ss][Dd][Dd]2$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	if database:get('bot:muteallwarn'..msg.chat_id_) then
	mute_all = 'مفعل | 🔐'
	else
	mute_all = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:text:warn'..msg.chat_id_) then
	mute_text = 'مفعل | 🔐'
	else
	mute_text = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:photo:warn'..msg.chat_id_) then
	mute_photo = 'مفعل | 🔐'
	else
	mute_photo = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:video:warn'..msg.chat_id_) then
	mute_video = 'مفعل | 🔐'
	else
	mute_video = 'معطل | 🔓'
end

	if database:get('bot:spam:warn'..msg.chat_id_) then
	mute_spam = 'مفعل | 🔐'
	else
	mute_spam = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:gifs:warn'..msg.chat_id_) then
	mute_gifs = 'مفعل | 🔐'
	else
	mute_gifs = 'معطل | 🔓'
end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:music:warn'..msg.chat_id_) then
	mute_music = 'مفعل | 🔐'
	else
	mute_music = 'معطل | 🔓'
	end
	------------
	if database:get('bot:inline:warn'..msg.chat_id_) then
	mute_in = 'مفعل | 🔐'
	else
	mute_in = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:voice:warn'..msg.chat_id_) then
	mute_voice = 'مفعل | 🔐'
	else
	mute_voice = 'معطل | 🔓'
	end
    ------------
	if database:get('bot:links:warn'..msg.chat_id_) then
	mute_links = 'مفعل | 🔐'
	else
	mute_links = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
	if database:get('bot:sticker:warn'..msg.chat_id_) then
	lock_sticker = 'مفعل | 🔐'
	else
	lock_sticker = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
   if database:get('bot:cmd:warn'..msg.chat_id_) then
	lock_cmd = 'مفعل | 🔐'
	else
	lock_cmd = 'معطل | 🔓'
end

    if database:get('bot:webpage:warn'..msg.chat_id_) then
	lock_wp = 'مفعل | 🔐'
	else
	lock_wp = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:hashtag:warn'..msg.chat_id_) then
	lock_htag = 'مفعل | 🔐'
	else
	lock_htag = 'معطل | 🔓'
end
	if database:get('bot:pin:warn'..msg.chat_id_) then
	lock_pin = 'مفعل | 🔐'
	else
	lock_pin = 'معطل | 🔓'
	end 
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:tag:warn'..msg.chat_id_) then
	lock_tag = 'مفعل | 🔐'
	else
	lock_tag = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:location:warn'..msg.chat_id_) then
	lock_location = 'مفعل | 🔐'
	else
	lock_location = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:contact:warn'..msg.chat_id_) then
	lock_contact = 'مفعل | 🔐'
	else
	lock_contact = 'معطل | 🔓'
	end

    if database:get('bot:english:warn'..msg.chat_id_) then
	lock_english = 'مفعل | 🔐'
	else
	lock_english = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:arabic:warn'..msg.chat_id_) then
	lock_arabic = 'مفعل | 🔐'
	else
	lock_arabic = 'معطل | 🔓'
	end
--➖➖➖➖➖➖➖➖➖➖
    if database:get('bot:forward:warn'..msg.chat_id_) then
	lock_forward = 'مفعل | 🔐'
	else
	lock_forward = 'معطل | 🔓'
end
--➖➖➖➖➖➖➖➖➖➖
--➖➖➖➖➖➖➖➖➖➖
	local ex = database:ttl("bot:charge:"..msg.chat_id_)
                if ex == -1 then
				exp_dat = 'لا نهائي'
				else
				exp_dat = math.floor(ex / 86400) + 1
			    end
 	------------
	 local TXT = "`📌¦ `_اعدادات المجموعه بالتحذير_\n➖➖➖➖➖➖➖➖➖➖➖\n`📌¦ `_كل الوسائط_  : "..mute_all.."\n" .."`📌¦ `_الروابط_  : "..mute_links.."\n" .."`📌¦ `_الانلاين_  : "..mute_in.."\n" .."`📌¦ `_اللغه الانكليزيه_  : "..lock_english.."\n" .."`📌¦ `_اعاده توجيه_  : "..lock_forward.."\n" .."`📌¦ `_اللغه العربيه_  : "..lock_arabic.."\n" .."`📌¦ `_التاك_  : "..lock_htag.."\n".."`📌¦ `_المعرف_ : "..lock_tag.."\n" .."`📌¦ `_المواقع_ : "..lock_wp.."\n\n" .."`📌¦ `_الشبكات_ : "..lock_location.."\n"
.."`📌¦ `_الصور_ : "..mute_photo.."\n" .."`📌¦ `_الدردشه_ : "..mute_text.."\n" .."`📌¦ `_المتحركه_ : "..mute_gifs.."\n" .."`📌¦ `_الصوت_ : "..mute_voice.."\n" .."`📌¦ `_الاغاني_ : "..mute_music.."\n" .."`📌¦ `_الفيديو_ : "..mute_video.."\n`📌¦ `_الشارحه_ : "..lock_cmd.."\n"
.."`📌¦ `_انقظاء البوت_ : "..exp_dat.."\n" .."➖➖➖➖➖➖➖➖➖➖➖"
         send(msg.chat_id_, msg.id_, 1, TXT, 1, 'md')
    end
    
  	 if text:match("^[Ss] [Bb][Aa][Nn]$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	if database:get('bot:muteallban'..msg.chat_id_) then
	mute_all = '`lock | 🔐`'
	else
	mute_all = '`unlock | 🔓`'
	end
	------------
	if database:get('bot:text:ban'..msg.chat_id_) then
	mute_text = '`lock | 🔐`'
	else
	mute_text = '`unlock | 🔓`'
	end
	------------
	if database:get('bot:photo:ban'..msg.chat_id_) then
	mute_photo = '`lock | ��`'
	else
	mute_photo = '`unlock | 🔓`'
	end
	------------
	if database:get('bot:video:ban'..msg.chat_id_) then
	mute_video = '`lock | 🔐`'
	else
	mute_video = '`unlock | 🔓`'
end

	------------
	if database:get('bot:gifs:ban'..msg.chat_id_) then
	mute_gifs = '`lock | 🔐`'
	else
	mute_gifs = '`unlock | 🔓`'
	end
	------------
	if database:get('bot:music:ban'..msg.chat_id_) then
	mute_music = '`lock | 🔐`'
	else
	mute_music = '`unlock | 🔓`'
	end
	------------
	if database:get('bot:inline:ban'..msg.chat_id_) then
	mute_in = '`lock | 🔐`'
	else
	mute_in = '`unlock | 🔓`'
	end
	------------
	if database:get('bot:voice:ban'..msg.chat_id_) then
	mute_voice = '`lock | 🔐`'
	else
	mute_voice = '`unlock | 🔓`'
	end
    ------------
	if database:get('bot:links:ban'..msg.chat_id_) then
	mute_links = '`lock | 🔐`'
	else
	mute_links = '`unlock | 🔓`'
	end
    ------------
	if database:get('bot:sticker:ban'..msg.chat_id_) then
	lock_sticker = '`lock | 🔐`'
	else
	lock_sticker = '`unlock | 🔓`'
	end
	------------
   if database:get('bot:cmd:ban'..msg.chat_id_) then
	lock_cmd = '`lock | 🔐`'
	else
	lock_cmd = '`unlock | 🔓`'
end

    if database:get('bot:webpage:ban'..msg.chat_id_) then
	lock_wp = '`lock | 🔐`'
	else
	lock_wp = '`unlock | 🔓`'
	end
	------------
    if database:get('bot:hashtag:ban'..msg.chat_id_) then
	lock_htag = '`lock | 🔐`'
	else
	lock_htag = '`unlock | 🔓`'
	end
	------------
    if database:get('bot:tag:ban'..msg.chat_id_) then
	lock_tag = '`lock | 🔐`'
	else
	lock_tag = '`unlock | 🔓`'
	end
	------------
    if database:get('bot:location:ban'..msg.chat_id_) then
	lock_location = '`lock | 🔐`'
	else
	lock_location = '`unlock | 🔓`'
	end
	------------
    if database:get('bot:contact:ban'..msg.chat_id_) then
	lock_contact = '`lock | 🔐`'
	else
	lock_contact = '`unlock | 🔓`'
	end
	------------
    if database:get('bot:english:ban'..msg.chat_id_) then
	lock_english = '`lock | 🔐`'
	else
	lock_english = '`unlock | 🔓`'
	end
	------------
    if database:get('bot:arabic:ban'..msg.chat_id_) then
	lock_arabic = '`lock | 🔐`'
	else
	lock_arabic = '`unlock | 🔓`'
	end
	------------
    if database:get('bot:forward:ban'..msg.chat_id_) then
	lock_forward = '`lock | 🔐`'
	else
	lock_forward = '`unlock | 🔓`'
	end
	------------
	------------
	local ex = database:ttl("bot:charge:"..msg.chat_id_)
                if ex == -1 then
				exp_dat = '`NO Fanil`'
				else
				exp_dat = math.floor(ex / 86400) + 1
			    end
 	------------
	 local TXT = "*Group Settings Ban*\n======================\n*Ban all* : "..mute_all.."\n" .."*Ban Links* : "..mute_links.."\n" .."*Ban Inline* : "..mute_in.."\n" .."*Ban English* : "..lock_english.."\n" .."*Ban Forward* : "..lock_forward.."\n" .."*Ban Arabic* : "..lock_arabic.."\n" .."*Ban Hashtag* : "..lock_htag.."\n".."*Ban tag* : "..lock_tag.."\n" .."*Ban Webpage* : "..lock_wp.."\n" .."*Ban Location* : "..lock_location.."\n"
.."*Ban Photo* : "..mute_photo.."\n" .."*Ban Text* : "..mute_text.."\n" .."*Ban Gifs* : "..mute_gifs.."\n" .."*Ban Voice* : "..mute_voice.."\n" .."*Ban Music* : "..mute_music.."\n" .."*Ban Video* : "..mute_video.."\n*Ban Cmd* : "..lock_cmd.."\n"
.."*Expire* : "..exp_dat.."\n======================"
         send(msg.chat_id_, msg.id_, 1, TXT, 1, 'md')
    end
    
          local text = msg.content_.text_:gsub('اعدادات الطرد','sdd3')
  	 if text:match("^[Ss][Dd][Dd]3$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	if database:get('bot:muteallban'..msg.chat_id_) then
	mute_all = 'مفعل | 🔐'
	else
	mute_all = 'معطل | 🔓'
	end
	------------
	if database:get('bot:text:ban'..msg.chat_id_) then
	mute_text = 'مفعل | 🔐'
	else
	mute_text = 'معطل | 🔓'
	end
	------------
	if database:get('bot:photo:ban'..msg.chat_id_) then
	mute_photo = 'مفعل | 🔐'
	else
	mute_photo = 'معطل | 🔓'
	end
	------------
	if database:get('bot:video:ban'..msg.chat_id_) then
	mute_video = 'مفعل | 🔐'
	else
	mute_video = 'معطل | 🔓'
end
	------------
	if database:get('bot:gifs:ban'..msg.chat_id_) then
	mute_gifs = 'مفعل | 🔐'
	else
	mute_gifs = 'معطل | 🔓'
	end
	------------
	if database:get('bot:music:ban'..msg.chat_id_) then
	mute_music = 'مفعل | 🔐'
	else
	mute_music = 'معطل | 🔓'
	end
	------------
	if database:get('bot:inline:ban'..msg.chat_id_) then
	mute_in = 'مفعل | 🔐'
	else
	mute_in = 'معطل | 🔓'
	end
	------------
	if database:get('bot:voice:ban'..msg.chat_id_) then
	mute_voice = 'مفعل | 🔐'
	else
	mute_voice = 'معطل | 🔓'
	end
    ------------
	if database:get('bot:links:ban'..msg.chat_id_) then
	mute_links = 'مفعل | 🔐'
	else
	mute_links = 'معطل | 🔓'
	end
    ------------
	if database:get('bot:sticker:ban'..msg.chat_id_) then
	lock_sticker = 'مفعل | 🔐'
	else
	lock_sticker = 'معطل | 🔓'
	end
	------------
   if database:get('bot:cmd:ban'..msg.chat_id_) then
	lock_cmd = 'مفعل | 🔐'
	else
	lock_cmd = 'معطل | 🔓'
end

    if database:get('bot:webpage:ban'..msg.chat_id_) then
	lock_wp = 'مفعل | 🔐'
	else
	lock_wp = 'معطل | 🔓'
	end
	------------
    if database:get('bot:hashtag:ban'..msg.chat_id_) then
	lock_htag = 'مفعل | 🔐'
	else
	lock_htag = 'معطل | 🔓'
	end
	------------
    if database:get('bot:tag:ban'..msg.chat_id_) then
	lock_tag = 'مفعل | 🔐'
	else
	lock_tag = 'معطل | 🔓'
	end
	------------
    if database:get('bot:location:ban'..msg.chat_id_) then
	lock_location = 'مفعل | 🔐'
	else
	lock_location = 'معطل | 🔓'
	end
	------------
    if database:get('bot:contact:ban'..msg.chat_id_) then
	lock_contact = 'مفعل | 🔐'
	else
	lock_contact = 'معطل | 🔓'
	end
	------------
    if database:get('bot:english:ban'..msg.chat_id_) then
	lock_english = 'مفعل | 🔐'
	else
	lock_english = 'معطل | 🔓'
	end
	------------
    if database:get('bot:arabic:ban'..msg.chat_id_) then
	lock_arabic = 'مفعل | 🔐'
	else
	lock_arabic = 'معطل | 🔓'
	end
	------------
    if database:get('bot:forward:ban'..msg.chat_id_) then
	lock_forward = 'مفعل | 🔐'
	else
	lock_forward = 'معطل | 🔓'
	end
	------------
	------------
	local ex = database:ttl("bot:charge:"..msg.chat_id_)
                if ex == -1 then
				exp_dat = 'لا نهائي'
				else
				exp_dat = math.floor(ex / 86400) + 1
			    end
 	------------
	 local TXT = "`📌¦ `_اعدادات المجموعه بالطرد_\n➖➖➖➖➖➖➖➖➖➖➖\n`📌¦ `_كل الوسائط_  : "..mute_all.."\n" .."`📌¦ `_الروابط_  : "..mute_links.."\n" .."`📌¦ `_الانلاين_  : "..mute_in.."\n" .."`📌¦ `_اللغه الانكليزيه_  : "..lock_english.."\n" .."`📌¦ `_اعاده توجيه_  : "..lock_forward.."\n" .."`📌¦ `_اللغه العربيه_  : "..lock_arabic.."\n" .."`📌¦ `_التاك_  : "..lock_htag.."\n".."`📌¦ `_المعرف_ : "..lock_tag.."\n" .."`📌¦ `_المواقع_ : "..lock_wp.."\n\n" .."`📌¦ `_الشبكات_ : "..lock_location.."\n"
.."`📌¦ `_الصور_ : "..mute_photo.."\n" .."`📌¦ `_الدردشه_ : "..mute_text.."\n" .."`📌¦ `_المتحركه_ : "..mute_gifs.."\n" .."`📌¦ `_الصوت_ : "..mute_voice.."\n" .."`📌¦ `_الاغاني_ : "..mute_music.."\n" .."`📌¦ `_الفيديو_ : "..mute_video.."\n`📌¦ `_الشارحه_ : "..lock_cmd.."\n"
.."`📌¦ `_انقظاء البوت_ : "..exp_dat.."\n" .."➖➖➖➖➖➖➖➖➖➖➖"
         send(msg.chat_id_, msg.id_, 1, TXT, 1, 'md')
    end
    
    
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('كرر','echo')
  	if text:match("^echo (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local txt = {string.match(text, "^(echo) (.*)$")} 
         send(msg.chat_id_, msg.id_, 1, txt[2], 1, 'md')
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('وضع قوانين','setrules')
  	if text:match("^[Ss][Ee][Tt][Rr][Uu][Ll][Ee][Ss] (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local txt = {string.match(text, "^([Ss][Ee][Tt][Rr][Uu][Ll][Ee][Ss]) (.*)$")}
	database:set('bot:rules'..msg.chat_id_, txt[2])
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, "*> Your ID :* _"..msg.sender_user_id_.."_\n*> UserName :* "..get_info(msg.sender_user_id_).."\n_> Group rules upadted..._", 1, 'md')
   else 
         send(msg.chat_id_, msg.id_, 1, "`📌¦ `_ٱﯾدﯾك_ : _"..msg.sender_user_id_.."_\n`📌¦ `_معرفك_ : "..get_info(msg.sender_user_id_).."\n`📌¦ `_تم وضع قوانين للمجموعه_", 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
  	if text:match("^[Rr][Uu][Ll][Ee][Ss]$")or text:match("^القوانين$") then
	local rules = database:get('bot:rules'..msg.chat_id_)
	if rules then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Group Rules :*\n'..rules, 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_قوانين المجموعه هي_ :\n'..rules, 1, 'md')
end
    else
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*rules msg not saved!*', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_لم يتم حفظ اي قوانين_', 1, 'md')
end
	end
	end
	-----------------------------------------------------------------------------------------------
  	if text:match("^[Dd][Ee][Vv]$") or text:match("^المطور$") and msg.reply_to_message_id_ == 0 then
       sendContact(msg.chat_id_, msg.id_, 0, 1, nil, 9647731928959, 'يآسِر حسن ┋❥ Y A S S E R 💚 ♩', '', bot_id)
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('وضع اسم','setname')
		if text:match("^[Ss][Ee][Tt][Nn][Aa][Mm][Ee] (.*)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
	local txt = {string.match(text, "^([Ss][Ee][Tt][Nn][Aa][Mm][Ee]) (.*)$")}
	     changetitle(msg.chat_id_, txt[2])
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Group name updated!_\n'..txt[2], 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم تحديث اسم المجموعه الى_\n'..txt[2], 1, 'md')
         end
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ee][Tt][Pp][Hh][Oo][Tt][Oo]$") or text:match("^وضع صوره") and is_owner(msg.sender_user_id_, msg.chat_id_) then
          database:set('bot:setphoto'..msg.chat_id_..':'..msg.sender_user_id_,true)
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Please send a photo noew!_', 1, 'md')
else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_قم بارسال صوره الان_', 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('وضع وقت','setexpire')
	if text:match("^[Ss][Ee][Tt][Ee][Xx][Pp][Ii][Rr][Ee] (%d+)$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
		local a = {string.match(text, "^([Ss][Ee][Tt][Ee][Xx][Pp][Ii][Rr][Ee]) (%d+)$")} 
		 local time = a[2] * day
         database:setex("bot:charge:"..msg.chat_id_,time,true)
		 database:set("bot:enable:"..msg.chat_id_,true)
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Group Charged for_ *'..a[2]..'* _Days_', 1, 'md')
else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم وضع وقت انتهاء البوت_ *'..a[2]..'* _يوم_', 1, 'md')
end
  end
  
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Tt][Aa][Tt][Ss]") or text:match("^الوقت") and is_mod(msg.sender_user_id_, msg.chat_id_) then
    local ex = database:ttl("bot:charge:"..msg.chat_id_)
       if ex == -1 then
                if database:get('lang:gp:'..msg.chat_id_) then
		send(msg.chat_id_, msg.id_, 1, '_No fanil_', 1, 'md')
else 
		send(msg.chat_id_, msg.id_, 1, '`📌¦ `_لا نهائي_', 1, 'md')
end
       else
        local d = math.floor(ex / day ) + 1
                if database:get('lang:gp:'..msg.chat_id_) then
	   		send(msg.chat_id_, msg.id_, 1, d.." *Group Days*", 1, 'md')
else 
  	   		send(msg.chat_id_, msg.id_, 1, d.." `📌¦ `_يوم_", 1, 'md')
end
       end
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('وقت المجموع��','stats gp')
	if text:match("^[Ss][Tt][Aa][Tt][Ss] [Gg][Pp] (%d+)") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	local txt = {string.match(text, "^([Ss][Tt][Aa][Tt][Ss] [Gg][Pp]) (%d+)$")} 
    local ex = database:ttl("bot:charge:"..txt[2])
       if ex == -1 then
                if database:get('lang:gp:'..msg.chat_id_) then
		send(msg.chat_id_, msg.id_, 1, '_No fanil_', 1, 'md')
else 
		send(msg.chat_id_, msg.id_, 1, '`📌¦ `_لا نهائي_', 1, 'md')
end
       else
        local d = math.floor(ex / day ) + 1
                if database:get('lang:gp:'..msg.chat_id_) then
	   		send(msg.chat_id_, msg.id_, 1, d.." *Group is Days*", 1, 'md')
   		else 
	   		send(msg.chat_id_, msg.id_, 1, d.." `📌¦ `_يوم_", 1, 'md')
end
       end
    end
	-----------------------------------------------------------------------------------------------
	 if is_sudo(msg) then
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('مغادره','leave')
  if text:match("^[Ll][Ee][Aa][Vv][Ee] (-%d+)") and is_admin(msg.sender_user_id_, msg.chat_id_) then
  	local txt = {string.match(text, "^([Ll][Ee][Aa][Vv][Ee]) (-%d+)$")} 
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(msg.chat_id_, msg.id_, 1, '*Group* '..txt[2]..' *remov*', 1, 'md')
   else 
	   send(msg.chat_id_, msg.id_, 1, '`📌¦ `_المجموعه_ '..txt[2]..' `📌¦ `_تم مغادرتها_', 1, 'md')
end
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(txt[2], 0, 1, '*Error*\n_Group is not my_', 1, 'md')
	else 
	   send(txt[2], 0, 1, '`📌¦ `_هذه ليست ضمن المجموعات الخاصه بي_', 1, 'md')
end
	   chat_leave(txt[2], bot_id)
  end
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('المده 1','plan1')
  if text:match('^[Pp][Ll][Aa][Nn]1 (-%d+)') and is_admin(msg.sender_user_id_, msg.chat_id_) then
       local txt = {string.match(text, "^([Pp][Ll][Aa][Nn]1) (-%d+)$")} 
       local timeplan1 = 2592000
       database:setex("bot:charge:"..txt[2],timeplan1,true)
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(msg.chat_id_, msg.id_, 1, '_Group_ '..txt[2]..' *Done 30 Days Active*', 1, 'md')
   else 
	   send(msg.chat_id_, msg.id_, 1, '`📌¦ `_المجموعه_'..txt[2]..' `📌¦ `_تم اعاده تفعيلها 30 يوم_', 1, 'md')
end
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(txt[2], 0, 1, '*Done 30 Days Active*', 1, 'md')
else 
	   send(txt[2], 0, 1, '`📌¦`_تم تفعيل المجموعه 30 يوم_', 1, 'md')
end
	   for k,v in pairs(sudo_users) do
                if database:get('lang:gp:'..msg.chat_id_) then
	      send(v, 0, 1, "*User "..msg.sender_user_id_.." Added bot to new group*" , 1, 'md')
else
	      send(v, 0, 1, "`📌¦ `_ٱﯾدﯾك_ : "..msg.sender_user_id_.." `📌¦ `_قمت بتفعيل مجموعه_" , 1, 'md')
end
       end
	   database:set("bot:enable:"..txt[2],true)
  end
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('المده 2','plan2')
  if text:match('^[Pp][Ll][Aa][Nn]2(-%d+)') and is_admin(msg.sender_user_id_, msg.chat_id_) then
       local txt = {string.match(text, "^([Pp][Ll][Aa][Nn]2)(-%d+)$")} 
       local timeplan2 = 7776000
       database:setex("bot:charge:"..txt[2],timeplan2,true)
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(msg.chat_id_, msg.id_, 1, '_Group_ '..txt[2]..' *Done 90 Days Active*', 1, 'md')
	 else 
	   send(msg.chat_id_, msg.id_, 1, '`📌¦ `_المجموعه_'..txt[2]..' `📌¦ `_تم اعاده تفعيلها 90 يوم_', 1, 'md')
end
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(txt[2], 0, 1, '*Done 90 Days Active*', 1, 'md')
   else 
	   send(txt[2], 0, 1, '`📌¦`_تم تفعيل المجموعه 90 يوم_', 1, 'md')
end
	   for k,v in pairs(sudo_users) do
                if database:get('lang:gp:'..msg.chat_id_) then
	      send(v, 0, 1, "*User "..msg.sender_user_id_.." Added bot to new group*" , 1, 'md')
else
	      sesend(v, 0, 1, "`📌¦ `_ٱﯾدﯾك_ : "..msg.sender_user_id_.." `📌¦ `_قمت بتفعيل مجموعه_" , 1, 'md')
end
       end
	   database:set("bot:enable:"..txt[2],true)
  end
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('المده 3','plan3')
  if text:match('^[Pp][Ll][Aa][Nn]3(-%d+)') and is_admin(msg.sender_user_id_, msg.chat_id_) then
       local txt = {string.match(text, "^([Pp][Ll][Aa][Nn]3)(-%d+)$")} 
       database:set("bot:charge:"..txt[2],true)
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(msg.chat_id_, msg.id_, 1, '_Group_ '..txt[2]..' *Done Days No Fanil Active*', 1, 'md')
	 else 
	   send(msg.chat_id_, msg.id_, 1, '`📌¦ `_المجموعه_'..txt[2]..' `📌¦ `_تم اعاده تفعيل المجموعه لا نهائي_    ', 1, 'md')
end
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(txt[2], 0, 1, '*Done Days No Fanil Active*', 1, 'md')
else 
	   send(txt[2], 0, 1, '`📌¦`_تم اعاده تفعيل المجموعه لا نهائي_', 1, 'md')
end
	   for k,v in pairs(sudo_users) do
                if database:get('lang:gp:'..msg.chat_id_) then
	      send(v, 0, 1, "*User "..msg.sender_user_id_.." Added bot to new group*" , 1, 'md')
else
	      send(v, 0, 1, "`📌¦ `_ٱﯾدﯾك_ : "..msg.sender_user_id_.." `📌¦ `_قمت بتفعيل مجموعه_" , 1, 'md')
end
       end
	   database:set("bot:enable:"..txt[2],true)
  end
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('تفعيل','add')
  if text:match('^[Aa][Dd][Dd]$') and is_admin(msg.sender_user_id_, msg.chat_id_) then
       local txt = {string.match(text, "^([Aa][Dd][Dd])$")} 
    if database:get("bot:charge:"..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '*Bot is already Added Group*', 1, 'md')
    else
      send(msg.chat_id_, 0, 1,'`📌¦`_ المجموعه بالتاكيد مفعله _'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
                  end
       if not database:get("bot:charge:"..msg.chat_id_) then
       database:set("bot:charge:"..msg.chat_id_,true)
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(msg.chat_id_, msg.id_, 1, "*> Your ID :* _"..msg.sender_user_id_.."_\n*> Bot Added To Group*", 1, 'md')
   else 
send(msg.chat_id_, 0, 1, "`🔹➖` _تم تفعيل المجموعه_ : \n `📌¦` _ايدي المطور_  : "..msg.sender_user_id_.."\n`📌¦` _معرف المطور_  : "..get_info(msg.sender_user_id_).."\n\n`🔹➖` _معلومات المجموعه_  :\n `📌¦` _ايدي المجموعه_  : "..msg.chat_id_.."\n`📌¦` _اسم المجموعه_ : "..chat.title_ , 1, 'md')
end
	   for k,v in pairs(sudo_users) do
                if database:get('lang:gp:'..msg.chat_id_) then
	      send(v, 0, 1, "*> Your ID :* _"..msg.sender_user_id_.."_\n*> added bot to new group*" , 1, 'md')
      else 
send(v,  0, 1, "`🔹➖` _قمت بتفعيل مجموعه جديده_ : \n `📌¦` _ايدي المطور_  : "..msg.sender_user_id_.."\n`📌¦` _معرف المطور_  : "..get_info(msg.sender_user_id_).."\n\n`🔹➖` _معلومات المجموعه_  :\n `📌¦` _ايدي المجموعه_  : "..msg.chat_id_.."\n`📌¦` _اسم المجموعه_ : "..chat.title_ , 1, 'md')
end
       end
	   database:set("bot:enable:"..msg.chat_id_,true)
  end
end
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('تعطيل','rem')
  if text:match('^[Rr][Ee][Mm]$') and is_admin(msg.sender_user_id_, msg.chat_id_) then
       local txt = {string.match(text, "^([Rr][Ee][Mm])$")} 
      if not database:get("bot:charge:"..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '*Bot is already remove Group*', 1, 'md')
    else 
      send(msg.chat_id_, 0, 1,'`📌¦` _المجموعه بالفعل معطله_ '..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
                  end
      if database:get("bot:charge:"..msg.chat_id_) then
       database:del("bot:charge:"..msg.chat_id_)
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(msg.chat_id_, msg.id_, 1, "*> Your ID :* _"..msg.sender_user_id_.."_\n*> Bot Removed To Group!*", 1, 'md')
   else 
send(msg.chat_id_, 0, 1, "`🔹➖` _تم تعطيل المجموعه_ : \n `📌¦` _ايدي المطور_  : "..msg.sender_user_id_.."\n`📌¦` _معرف المطور_  : "..get_info(msg.sender_user_id_).."\n\n`🔹➖` _معلومات المجموعه_  :\n `📌¦` _ايدي المجموعه_  : "..msg.chat_id_.."\n`📌¦` _اسم المجموعه_ : "..chat.title_ , 1, 'md')
end
	   for k,v in pairs(sudo_users) do
                if database:get('lang:gp:'..msg.chat_id_) then
	      send(v, 0, 1, "*> Your ID :* _"..msg.sender_user_id_.."_\n*> Removed bot from new group*" , 1, 'md')
      else 
send(v,  0, 1, "`🔹➖` _قمت بتعطيل مجموعه _ : \n `📌¦` _ايدي المطور_  : "..msg.sender_user_id_.."\n`📌¦` _معرف المطور_  : "..get_info(msg.sender_user_id_).."\n\n`🔹➖` _معلومات المجموعه_  :\n `📌¦` _ايدي المجموعه_  : "..msg.chat_id_.."\n`📌¦` _اسم المجموعه_ : "..chat.title_ , 1, 'md')
end
       end
  end
  end
              
  -----------------------------------------------------------------------------------------------
          if text:match('^[Jj][Oo][Ii][Nn] (-%d+)') and is_admin(msg.sender_user_id_, msg.chat_id_) then
       local txt = {string.match(text, "^([Jj][Oo][Ii][Nn]) (-%d+)$")} 
	   send(msg.chat_id_, msg.id_, 1, '_Group_ '..txt[2]..' *is join*', 1, 'md')
	   send(txt[2], 0, 1, '*Sudo Joined To Grpup*', 1, 'md')
	   add_user(txt[2], msg.sender_user_id_, 10)
  end
  -----------------------------------------------------------------------------------------------
   if text:match('^اضافه (-%d+)') and is_admin(msg.sender_user_id_, msg.chat_id_) then
       local txt = {string.match(text, "^(اضافه) (-%d+)$")} 
	   send(msg.chat_id_, msg.id_, 1, '● - `المجموعه` '..txt[2]..' `تم اضافتك لها ` ☑️', 1, 'md')
	   send(txt[2], 0, 1, '● - `تم اضافه المطور للمجموعه` ✔️📍', 1, 'md')
	   add_user(txt[2], msg.sender_user_id_, 10)
  end
   -----------------------------------------------------------------------------------------------
  end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Rr][Ee][Ll][Oo][Aa][Dd]$") or text:match("^تحديث") and is_sudo(msg) then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Reloaded*', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم تحديث البوت_', 1, 'md')
end
    end
    
     if text:match("^[Dd][Ee][Ll]") or text:match("^مسح") and msg.reply_to_message_id_ ~= 0 and is_mod(msg.sender_user_id_, msg.chat_id_) then
     delete_msg(msg.chat_id_, {[0] = msg.reply_to_message_id_})
     delete_msg(msg.chat_id_, {[0] = msg.id_})
            end
	----------------------------------------------------------------------------------------------
   if text:match('^تنظيف (%d+)$') and is_sudo(msg) then
  local matches = {string.match(text, "^(تنظيف) (%d+)$")}
   if msg.chat_id_:match("^-100") then
    if tonumber(matches[2]) > 100 or tonumber(matches[2]) < 1 then
      pm = '`📌¦` _لا تستطيع حذف اكثر من 1000 رساله_'
    send(msg.chat_id_, msg.id_, 1, pm, 1, 'md')
                  else
      tdcli_function ({
     ID = "GetChatHistory",
       chat_id_ = msg.chat_id_,
          from_message_id_ = 0,
   offset_ = 0,
          limit_ = tonumber(matches[2])
    }, delmsg, nil)
      pm =  '`📌¦ `'..matches[2]..'  _من الرسائل تم حذفها_ '
           send(msg.chat_id_, msg.id_, 1, pm, 1, 'md')
       end
        else pm ='<code>📌¦ هناك خطا !<code>'
      send(msg.chat_id_, msg.id_, 1, pm, 1, 'html')
              end
            end


   if text:match('^[Dd]el (%d+)$') and is_sudo(msg) then
  local matches = {string.match(text, "^([Dd]el) (%d+)$")}
   if msg.chat_id_:match("^-100") then
    if tonumber(matches[2]) > 100 or tonumber(matches[2]) < 1 then
      pm = '<b>> Error</b>\n<b>use /del [1-1000] !<bb>'
    send(msg.chat_id_, msg.id_, 1, pm, 1, 'html')
                  else
      tdcli_function ({
     ID = "GetChatHistory",
       chat_id_ = msg.chat_id_,
          from_message_id_ = 0,
   offset_ = 0,
          limit_ = tonumber(matches[2])
    }, delmsg, nil)
      pm ='> <i>'..matches[2]..'</i> <b>Last Msgs Has Been Removed.</b>'
           send(msg.chat_id_, msg.id_, 1, pm, 1, 'html')
       end
        else pm ='<b>> found!<b>'
      send(msg.chat_id_, msg.id_, 1, pm, 1, 'html')
                end
              end

          local text = msg.content_.text_:gsub('حفظ','note')
    if text:match("^[Nn][Oo][Tt][Ee] (.*)$") and is_sudo(msg) then
    local txt = {string.match(text, "^([Nn][Oo][Tt][Ee]) (.*)$")}
      database:set('owner:note1', txt[2])
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '*save!*', 1, 'md')
    else 
      send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم حفظ الكليشه_', 1, 'md')
end
    end

    if text:match("^[Dd][Nn][Oo][Tt][Ee]$") or text:match("^حذف الكليشه$") and is_sudo(msg) then
      database:del('owner:note1',msg.chat_id_)
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '*Deleted!*', 1, 'md')
    else 
      send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم حذف الكليشه_', 1, 'md')
end
      end
  -----------------------------------------------------------------------------------------------
    if text:match("^[Gg][Ee][Tt][Nn][Oo][Tt][Ee]$") or text:match("^جلب الكليشه$") and is_sudo(msg) then
    local note = database:get('owner:note1')
	if note then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Note is :-*\n'..note, 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦ الكليشه المحفوظه :- `\n'..note, 1, 'md')
end
    else
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Note msg not saved!*', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_لايوجد كليشه محفوظه_', 1, 'md')
end
	end
end

  if text:match("^[Ss][Ee][Tt][Ll][Aa][Nn][Gg] (.*)$") or text:match("^تحويل (.*)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
    local langs = {string.match(text, "^(.*) (.*)$")}
  if langs[2] == "ar" or langs[2] == "عربيه" then
  if not database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '`📌¦ `_بالفعل تم وضع العربيه للبوت_', 1, 'md')
    else
      send(msg.chat_id_, msg.id_, 1, '`📌¦ `_ تم وضع العربيه للبوت_', 1, 'md')
       database:del('lang:gp:'..msg.chat_id_)
    end
    end
  if langs[2] == "en" or langs[2] == "انكليزيه" then
  if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '_> Language Bot is already_ *English*', 1, 'md')
    else
      send(msg.chat_id_, msg.id_, 1, '> _Language Bot has been changed to_ *English* !', 1, 'md')
        database:set('lang:gp:'..msg.chat_id_,true)
    end
    end
    end
	-----------------------------------------------------------------------------------------------
	
if  text:match("^$") or text:match("^ايدي$") and msg.reply_to_message_id_ == 0 then
local function getpro(extra, result, success)
local user_msgs = database:get('user:msgs'..msg.chat_id_..':'..msg.sender_user_id_)
   if result.photos_[0] then
          if database:get('lang:gp:'..msg.chat_id_) then
            sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[0].sizes_[1].photo_.persistent_id_,"> Group ID : "..msg.chat_id_:gsub('-100','').."\n> Your ID : "..msg.sender_user_id_.."\n> UserName : "..get_info(msg.sender_user_id_).."\n> Msgs : "..user_msgs,msg.id_,msg.id_.."")
  else 
            sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[0].sizes_[1].photo_.persistent_id_, "📌¦ صوره حسابك 🙄🖕🏼".."\n".."📌¦ ايدي المجموعه : "..msg.chat_id_:gsub('-100','').."\n📌¦ ٱﯾدﯾك : "..msg.sender_user_id_.."\n📌¦ معرفك : "..get_info(msg.sender_user_id_).."\n📌¦ رسائلك : "..user_msgs,msg.id_,msg.id_.."تابع @ll011ll", 1, 'md')
end
   else
          if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "You Have'nt Profile Photo!!\n\n> *> Group ID :* "..msg.chat_id_:gsub('-100','').."\n*> Your ID :* "..msg.sender_user_id_.."\n*> UserName :* "..get_info(msg.sender_user_id_).."\n*> Msgs : *_"..user_msgs.."_", 1, 'md')
   else 
      send(msg.chat_id_, msg.id_, 1, "`📌¦ `_انت لا تملك صوره ي حسابك_\n\n`📌¦ `_ايدي المجموعه_ : "..msg.chat_id_:gsub('-100','').."\n`📌¦ `_ٱﯾدﯾك_ : "..msg.sender_user_id_.."\n`📌¦ `_معرفك_ : "..get_info(msg.sender_user_id_).."\n`📌¦ `_رسائلك_ : _"..user_msgs.."_", 1, 'md')
end
   end
   end
   tdcli_function ({
    ID = "GetUserProfilePhotos",
    user_id_ = msg.sender_user_id_,
    offset_ = 0,
    limit_ = 1
  }, getpro, nil)
end

if text:match("^$") or text:match("^معلوماتي$") and msg.reply_to_message_id_ == 0 then
local user_msgs = database:get('user:msgs'..msg.chat_id_..':'..msg.sender_user_id_)
          function get_me(extra,result,success)
      if is_sudo(msg) then
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'Sudo'
      else
      t = 'مطور البوت'
      end
      elseif is_admin(msg.sender_user_id_) then
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'Global Admin'
      else
      t = 'ادمن في البوت'
      end
      elseif is_owner(msg.sender_user_id_, msg.chat_id_) then
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'Group Owner'
      else
      t = 'مدير الكروب'
      end
      elseif is_mod(msg.sender_user_id_, msg.chat_id_) then
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'Group Moderator'
      else
      t = 'ادمن الكروب'
      end
      else
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'Group Member'
      else
      t = 'عضو فقط'
      end
    end
    if result.username_ then
    result.username_ = '@'..result.username_
      else
    result.username_ = 'Not Found'
        end
    if result.last_name_ then
    lastname = result.last_name_
       else
    lastname = 'Not Found'
     end
    if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "> Group ID : "..msg.chat_id_:gsub('-100','').."\n> Your ID : "..msg.sender_user_id_.."\n> Your Name : "..result.first_name_.."\n> UserName : "..result.username_.."\n> Your Rank : "..t.."\n> Msgs : "..user_msgs.."", 1, 'rrr')
       else
      send(msg.chat_id_, msg.id_, 1, "📌¦ ايدي المجموعه : "..msg.chat_id_:gsub('-100','').."\n📌¦ ايديك : "..msg.sender_user_id_.."\n📌¦ اسمك : "..result.first_name_.."\n📌¦ معرفك : "..result.username_.."\n📌¦ موقعك : "..t.."\n📌¦ رسائلك : "..user_msgs.."", 1, 'rrr')
      end
    end
          getUser(msg.sender_user_id_,get_me)
  end

   if text:match('^اظهر حساب (%d+)') and is_sudo(msg) then
        local id = text:match('^اظهر حساب (%d+)')
        local text = '📌¦ اضغط لمشاهدة الحساب'
      tdcli_function ({ID="SendMessage", chat_id_=msg.chat_id_, reply_to_message_id_=msg.id_, disable_notification_=0, from_background_=1, reply_markup_=nil, input_message_content_={ID="InputMessageText", text_=text, disable_web_page_preview_=1, clear_draft_=0, entities_={[0] = {ID="MessageEntityMentionName", offset_=0, length_=19, user_id_=id}}}}, dl_cb, nil)
   end 

   if text:match('^[Ww][Hh][Oo][Ii][Ss] (%d+)') and is_sudo(msg) then
        local id = text:match('^[Ww][Hh][Oo][Ii][Ss] (%d+)')
        local text = 'Click to view user!'
      tdcli_function ({ID="SendMessage", chat_id_=msg.chat_id_, reply_to_message_id_=msg.id_, disable_notification_=0, from_background_=1, reply_markup_=nil, input_message_content_={ID="InputMessageText", text_=text, disable_web_page_preview_=1, clear_draft_=0, entities_={[0] = {ID="MessageEntityMentionName", offset_=0, length_=19, user_id_=id}}}}, dl_cb, nil)
   end
   -----------------------------------------------------------------------------------------------
   if text:match("^[Pp][Ii][Nn]$") or text:match("^تثبيت$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
       pin(msg.chat_id_,msg.reply_to_message_id_,0)
	   database:set('pinnedmsg'..msg.chat_id_,msg.reply_to_message_id_)
          if database:get('lang:gp:'..msg.chat_id_) then
	            send(msg.chat_id_, msg.id_, 1, '_Msg han been_ *pinned!*', 1, 'md')
	           else 
	            send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم تثبيت الرساله_', 1, 'md')
end
 end

   if text:match("^[Vv][Ii][Ee][Ww]$") or text:match("^مشاهده منشور$") then
        database:set('bot:viewget'..msg.sender_user_id_,true)
    if database:get('lang:gp:'..msg.chat_id_) then
        send(msg.chat_id_, msg.id_, 1, '*Please send a post now!*', 1, 'md')
      else 
        send(msg.chat_id_, msg.id_, 1, '`📌¦ `_قم باعاده توجيه المنشور الان _', 1, 'md')
end
   end
  end
   -----------------------------------------------------------------------------------------------
   if text:match("^[Uu][Nn][Pp][Ii][Nn]$") or text:match("^الغاء تثبيت$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
         unpinmsg(msg.chat_id_)
          if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Pinned Msg han been_ *unpinned!*', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`📌¦ `_تم الغاء تثبيت الرساله_', 1, 'md')
end
 end
 ---------------------------------------------------------------------------------------------------
 
   if text == "unlock reply" and is_owner(msg.sender_user_id_, msg.chat_id_) or text == "Unlock Reply" and is_owner(msg.sender_user_id_, msg.chat_id_) or text == "تفعيل الردود" and is_owner(msg.sender_user_id_, msg.chat_id_) then
  if not database:get('bot:rep:mute'..msg.chat_id_) then
  if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '> *Replies is already enabled*️', 1, 'md')
else
send(msg.chat_id_, 0, 1,'`📌¦`_الردود بالتاكيد مفعله_'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
end
  else
  if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '> *Replies has been enable*️', 1, 'md')
    else
send(msg.chat_id_, 0, 1,'`📌¦` _تم تفعيل الردود_'..'\n'..'`����¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
database:del('bot:rep:mute'..msg.chat_id_)
      end
    end
    end
  if text == "lock reply" and is_owner(msg.sender_user_id_, msg.chat_id_) or text == "Lock Reply" and is_owner(msg.sender_user_id_, msg.chat_id_) or text == "تعطيل الردود" and is_owner(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:rep:mute'..msg.chat_id_) then
  if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '> *Replies is already disabled*️', 1, 'md')
    else
send(msg.chat_id_, 0, 1,'`📌¦` _الردود بالتاكيد معطله_'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
      end
    else
  if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '> *Replies has been disable*️', 1, 'md')
    else
send(msg.chat_id_, 0, 1,'`📌¦` _تم تعطيل الردود_'..'\n'..'`📌¦` _ٱﯾدﯾك_ : '..msg.sender_user_id_..'\n`📌¦`_ بۈاسطهۃ_ : '..get_info(msg.sender_user_id_)..' ♩', 1, 'md')
        database:set('bot:rep:mute'..msg.chat_id_,true)
      end
    end
  end
	-----------------------------------------------------------------------------------------------
   if text:match("^[Ii][Dd][Gg][Pp]$") or text:match("^ايدي المجموعه$") then
    send(msg.chat_id_, msg.id_, 1, "*"..msg.chat_id_.."*", 1, 'md')
  end
   -----------------------------------------------------------------------------------------------
   if text:match("^[Hh][Ee][Ll][Pp]") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
`هناك`  *6* `اوامر لعرضها`
*======================*
*h1* `لعرض اوامر الحمايه`
*======================*
*h2* `لعرض اوامر الحمايه بالتحذير`
*======================*
*h3* `لعرض اوامر الحمايه بالطرد`
*======================*
*h4* `لعرض اوامر الادمنيه`
*======================*
*h5* `لعرض اوامر المجموعه`
*======================*
*h6* `لعرض اوامر المطورين`
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^[Hh]1") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*lock* `للقفل`
*unlock* `للفتح`
*======================*
*| links |* `��لروابط`
*| tag |* `المعرف`
*| hashtag |* `التاك`
*| cmd |* `السلاش`
*| edit |* `التعديل`
*| webpage |* `الروابط الخارجيه`
*======================*
*| flood ban |* `التكرار بالطرد`
*| flood mute |* `التكرار بالكتم`
*| gif |* `الصور المتحركه`
*| photo |* `الصور`
*| sticker |* `الملصقات`
*| video |* `الفيديو`
*| inline |* `لستات شفافه`
*======================*
*| text |* `الدردشه`
*| fwd |* `التوجيه`
*| music |* `الاغاني`
*| voice |* `الصوت`
*| contact |* `جهات الاتصال`
*| service |* `اشعارات الدخول`
*======================*
*| location |* `المواقع`
*| bots |* `البوتات`
*| spam |* `الكلايش`
*| arabic |* `العربيه`
*| english |* `الانكليزيه`
*| all |* `كل الميديا`
*| all |* `مع العدد قفل الميديا بالثواني`
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^[Hh]2") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*lock* `للقفل`
*unlock* `للفتح`
*======================*
*| links warn |* `الروابط`
*| tag warn |* `المعرف`
*| hashtag warn |* `التاك`
*| cmd warn |* `السلاش`
*| webpage warn |* `الروابط الخارجيه`
*======================*
*| gif warn |* `الصور المتحركه`
*| photo warn |* `الصور`
*| sticker warn |* `الملصقات`
*| video warn |* `الفيديو`
*| inline warn |* `لستات شفافه`
*======================*
*| text warn |* `الدردشه`
*| fwd warn |* `التوجيه`
*| music warn |* `الاغاني`
*| voice warn |* `الصوت`
*| contact warn |* `جهات الاتصال`
*======================*
*| location warn |* `المواقع`
*| spam |* `الكلايش`
*| arabic warn |* `العربيه`
*| english warn |* `الانكليزيه`
*| all warn |* `كل الميديا`
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^[Hh]3") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*lock* `للقفل`
*unlock* `للفتح`
*======================*
*| links ban |* `الروابط`
*| tag ban |* `المعرف`
*| hashtag ban |* `التاك`
*| cmd ban |* `السلاش`
*| webpage ban |* `الروابط الخارجيه`
*======================*
*| gif ban |* `الصور المتحركه`
*| photo ban |* `الصور`
*| sticker ban |* `الملصقات`
*| video ban |* `الفيديو`
*| inline ban |* `لستات شفافه`
*======================*
*| text ban |* `الدردشه`
*| fwd ban |* `التوجيه`
*| music ban |* `الاغاني`
*| voice ban |* `الصوت`
*| contact ban |* `جهات الاتصال`
*| location ban |* `المواقع`
*======================*
*| arabic ban |* `العربيه`
*| english ban |* `الانكليزيه`
*| all ban |* `كل الميديا`
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^[Hh]4") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*======================*
*| setmote |* `رفع ادمن` 
*| remmote |* `ازاله ادمن` 
*| setlang en |* `تغير اللغه للانكليزيه` 
*| setlang ar |* `تغير اللغه للعربيه` 
*| unsilent |* `لالغاء كتم العضو` 
*| silent |* `لكتم عضو` 
*| ban |* `حظر عضو` 
*| unban |* `الغاء حظر العضو` 
*| id |* `لاظهار الايدي [بالرد] `
*| pin |* `تثبيت رساله!`
*| unpin |* `الغاء تثبيت الرساله!`
*======================*
*| s del |* `اظهار اعدادات المسح`
*| s warn |* `اظهار اعدادات التحذير`
*| s ban |* `اظهار اعدادات الطرد`
*| silentlist |* `اظهار المكتومين`
*| banlist |* `اظهار المحظورين`
*| modlist |* `اظهار الادمنيه`
*| del |* `حذف رساله بالرد`
*| link |* `اظهار الرابط`
*| rules |* `اظهار القوانين`
*======================*
*| bad |* `منع كلمه` 
*| unbad |* `الغاء منع كلمه` 
*| badlist |* `اظهار الكلمات الممنوعه` 
*| stats |* `لمعرفه ايام البوت`
*| del wlc |* `حذف الترحيب` 
*| set wlc |* `وضع الترحيب` 
*| wlc on |* `تفعيل الترحيب` 
*| wlc off |* `تعطيل الترحيب` 
*| get wlc |* `معرفه الترحيب الحالي` 
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end

   if text:match("^[Hh]5") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*======================*
*clean* `مع الاوامر ادناه بوضع فراغ`

*| banlist |* `المحظورين`
*| badlist |* `كلمات المحظوره`
*| modlist |* `الادمنيه`
*| link |* `الرابط المحفوظ`
*| silentlist |* `المكتومين`
*| bots |* `بوتات تفليش وغيرها`
*| rules |* `القوانين`
*======================*
*set* `مع الاوامر ادناه بدون فراغ`

*| link |* `لوضع رابط`
*| rules |* `لوضع قوانين`
*| name |* `مع الاسم لوضع اسم`
*| photo |* `لوضع صوره`

*======================*

*| flood ban |* `وضع تكرار بالطرد`
*| flood mute |* `وضع تكرار بالكتم`
*| flood time |* `لوضع زمن تكرار بالطرد او الكتم`
*| spam del |* `وضع عدد السبام بالمسح`
*| spam warn |* `وضع عدد السبام بالتحذير`
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^[Hh]6") and is_sudo(msg) then
   
   local text =  [[
*======================*
*| add |* `تفعيل البوت`
*| rem |* `تعطيل البوت`
*| setexpire |* `وضع ايام للبوت`
*| stats gp |* `لمعرفه ايام البوت`
*| plan1 + id |* `تفعيل البوت 30 يوم`
*| plan2 + id |* `تفعيل البوت 90 يوم`
*| plan3 + id |* `تفعيل البوت لا نهائي`
*| join + id |* `لاضافتك للكروب`
*| leave + id |* `لخروج البوت`
*| leave |* `لخروج البوت`
*| stats gp + id |* `لمعرفه  ايام البوت`
*| view |* `لاظهار مشاهدات منشور`
*| note |* `لحفظ كليشه`
*| dnote |* `لحذف الكليشه`
*| getnote |* `لاظهار الكليشه`
*| reload |* `لتنشيط البوت`
*| clean gbanlist |* `لحذف الحظر العام`
*| clean owners |* `لحذف قائمه المدراء`
*| adminlist |* `لاظهار ادمنيه البوت`
*| gbanlist |* `لاظهار المحظورين عام `
*| ownerlist |* `لاظهار مدراء ال��وت`
*| setadmin |* `لاضافه ادمن`
*| remadmin |* `لحذف ادمن`
*| setowner |* `لاضافه مدير`
*| remowner |* `لحذف مدير`
*| banall |* `لحظر العام`
*| unbanall |* `لالغاء العام`
*| groups |* `عدد كروبات البوت`
*| bc |* `لنشر شئ`
*| show edit |* `لكشف التعديل`
*| del |* `ويه العدد حذف رسائل`
*| whois |* `مع الايدي لعرض صاحب الايدي`
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   
   
   if text:match("^الاوامر") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
🔸➖ `هنالك `*4* `اوامر لعرضهآ`
*ء➖➖➖➖➖➖➖➖➖➖ء*

🔹➖ *م1* ` اوامر الحماية`

🔹➖ *م2*  `اوامر الادمنيه`

🔹➖ *م3* `اوامر المجموعه`

🔹➖ *م4*  `اوامر المطور`

*ء➖➖➖➖➖➖➖➖➖➖ء*

]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^م1") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
اوامر الحمايه 
ء➖➖➖➖➖➖➖➖➖➖ء
🔹➖ قفل 🔒┋_لـقـفـل امـر_
🔸➖ فتح 🔓┋_لـفـتـح امـر_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦`  استخدم قفل اوفتح مع👇🏻

`📌¦` _الروابط • التوجيه • البوتات • المواقع • الشارحه • التعديل • التاك • المعرف • الدردشه • الاغاني • الصوت • الجهات • الشبكات • الدخول بالرابط • العربيه • الانكليزيه • الكلايش • الانلاين • الصور • المتحركه • الفيديو • الملصقات  • الكل • الكل بالثواني • الكل بالساعه • التكرار بالكتم • التكرار بالطرد_ 

ء➖➖➖➖➖➖➖➖➖➖ء
اوامر الحمايه بالتحذير
ء➖➖➖➖➖➖➖➖➖➖ء
🔹➖ قفل 🔒┋_لـقـفـل امـر_
🔸➖ فتح 🔓┋_لـفـتـح امـر_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦`  استخدم قفل اوفتح مع👇🏻

`📌¦` _الروابط بالتحذير • التوجيه بالتحذير • المواقع بالتحذير • الشارحه بالتحذير • التاك بالتحذير • المعرف بالتحذير • الدردشه بالتحذير • الاغاني بالتحذير • الصوت بالتحذير • الجهات بالتحذير • الشبكات بالتحذير • الدخول بالرابط بالتحذير • العربيه بالتحذير • الانكليزيه  بالتحذير • الكلايش بالتحذير • الانلاين بالتحذير • الصور بالتحذير • المتحركه بالتحذير • الفيديو بالتحذير • الملصقات بالتحذير • الكل بالتحذير •_

ء➖➖➖➖➖➖➖➖➖➖ء
اوامر الحمايه بالطرد
ء➖➖➖➖➖➖➖➖➖➖ء
🔹➖ قفل 🔒┋_لـقـفـل امـر_
🔸➖ فتح 🔓┋_لـفـتـح امـر_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦`  استخدم قفل اوفتح مع👇🏻

`📌¦` _الروابط بالطرد • التوجيه بالطرد • المواقع بالطرد • الشارحه بالطرد • التاك بالطرد • المعرف بالطرد • الدردشه بالطرد • الاغاني بالطرد • الصوت بالطرد • الجهات بالطرد • الشبكات بالطرد  • العربيه بالطرد • الانكليزيه  بالطرد • الكلايش بالطرد • الانلاين بالطرد • الصور بالطرد • المتحركه بالطرد • الفيديو بالطرد • الملصقات بالطرد  • الكل بالطرد •_

ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` _المطور_ : @Y3SOO
`📌¦` _قناة المطور_ : @ll011ll 🌸

]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^2م") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
🔹➖ اوامر الادمنيه 
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` كتم • _لكتم العظو_
`📌¦` الغاء كتم • _لالغاء كتم العظو_
`📌¦` المكتومين • _اضهار المكتومين_
`📌¦` رفع ادمن • _لرفع ادمن_
`📌¦` تنزيل ادمن • _لحذف ادمن_
`📌¦` مسح • _لحذف رساله بالرد_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` حظر • _لحظر عظو_
`📌¦` الغاء حظر • _الغاء الحظر للعظو_
`📌¦` تثبيت • _لتثبيت رساله_
`📌¦` الغاء التثبيت • _مسح الرساله المثبته_
`📌¦` حذف ترحيب • _لحذف الترحيب_
`📌¦` جلب ترحيب • _معرفه الترحيب الموجود_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` وضع ترحيب • _لاضافه ترحيب_
`📌¦` تفعيل الترحيب • _لتشغيل التوجيب_
`📌¦` تعطيل الترحيب • _لايقاف الترحيب_
`📌¦` ايدي • _لاضهار ايدي بالرد_
`📌¦` منع • _منع كلمه_
`📌¦` الغاء منع • _الغاء منع الكلمه_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` قائمه المنع • _لاضهار الكلمات الممنوعه_
`📌¦` الوقت • _ايام البوت_
`📌¦` تحويل انكليزيه • _لتغير لغه انكليزيه_
`📌¦` تحويل عربيه • _لتغير لغه عربيه_
`📌¦` القوانين • _لاضهار القوانين_
`📌¦` المحظورين • _لاضهار المحظورين_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` اعدادات الطرد • _لاضهار اعدادات الطرد_
`📌¦` اعدادات التحذير • _لاضهار اعدادات التحذير_
`📌¦` اعدادات المسح • _اضهار الاعدادات_

ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` _المطور_ : @Y3SOO
`📌¦` _قناة المطور_ : @ll011ll 🌸

]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end

   if text:match("^م3") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
🔹➖ _اوامر المجموعه_
ء➖➖➖➖➖➖➖➖➖➖ء

🔸➖ مسح • _مع الاوامر ادناه_

_المحظورين_ • _قائمه المنع_ • _الادمنيه_ • _الرابط_ • _المكتومين_ • _البوتات_ • _القوانين_

ء➖➖➖➖➖➖➖➖➖➖ء

🔹➖ وضع • _مع الاوامر ادناه_

_رابط_ • _اسم_ • _صوره_ • _قوانين_ • _ترحيب_• _تكرار بالطرد_ • _تكرار بالكتم_ • _زمن التكرار_ • _كلايش بالمسح_ • _كلايش بالتحذير_

ء➖➖➖➖➖➖➖➖➖➖ء

`📌¦` _المطور_ : @Y3SOO
`📌¦` _قناة المطور_ : @ll011ll 🌸
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^م4") and is_sudo(msg) then
   
   local text =  [[



🔹➖ _اوامر المطور_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` تفعيل • _تفعيل البوت_
`📌¦` تعطيل • _تعطيل البوت_
`📌¦` وضع وقت • _وضع ايام للبوت_
`📌¦` المده 1 + id • _تفعيل البوت 30 يوم_
`📌¦` المده 2 + id • _تفعيل البوت 90 يوم_
`📌¦` المده 3 + id • _تفعيل البوت لا نهائي_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` اضف + id • _لاضافتك للكروب_
`📌¦` مغادره + id • _لخروج البوت_
`📌¦` مغادره • _لخروج البوت_
`📌¦` وقت المجموعه + id • _لمعرفه ايام البوت_
`📌¦` مشاهده منشور • _لاظهار مشاهدات منشور_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` حفظ • _لحفظ كليشه_
`📌¦` حذف الكليشه • _لحذف الكليشه_
`📌¦` جلب الكليشه • _لاظهار الكليشه _
`📌¦` تحديث • _لتنشيط البوت_
`📌¦` مسح قائمه العام • _لحذف الحظر العام_
`📌¦` مسح المدراء • _لحذف قائمه المدراء_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` ادمنيه البوت  • _لاظهار ادمنيه البوت_
`📌¦` قائمه العام • _لاظهار المحظورين عام _
`📌¦` المدراء • _لاظهار مدراء البوت_
`📌¦` رفع ادمن للبوت • _لاضافه ادمن_
`📌¦` تنزيل ادمن للبوت • _لحذف ادمن_
`📌¦` رفع مدير • _لاضافه مدير_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` الكروبات • _عدد كروبات البوت_
`📌¦` تنزيل مدير • _لحذف مدير_
`📌¦` حظر عام • _لحظر العام_
`📌¦` الغاء العام • _لالغاء العام_
`📌¦` اذاعه • _لنشر شئ_
`📌¦` كشف التعديل • _لكشف التعديل_
`📌¦` تنظيف • _مع العدد حذف رسائل_
`📌¦` اظهر حساب • _ مع الايدي لعرض صاحب الايدي_
ء➖➖➖➖➖➖➖➖➖➖ء
`📌¦` _المطور_ : @Y3SOO
`📌¦` _قناة المطور_ : @ll011ll 🌸


]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
if text:match("^المطور") or text:match("^الاصدار") or text:match("^السورس") or text:match("^سورس") then
   
   local text =  [[
📌¦ _اهلا بك في بوت كوكي_
📌¦ _المطور_ : @Y3SOO
📌¦ _قناة المطور_ : @ll011ll

]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
  
  if text:match("^Me$") or text:match("^موقعي$") and msg.reply_to_message_id_ == 0 then
local user_msgs = database:get('user:msgs'..msg.chat_id_..':'..msg.sender_user_id_)
          function get_me(extra,result,success)
      if is_sudo(msg) then
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'انت المطور مالتي 🌝👅'
      else
      t = 'انت المطور مالتي 🌝👅'
      end
      elseif is_admin(msg.sender_user_id_) then
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'انت ادمن بالبوت 🌚💋'
      else
      t = 'انت ادمن بالبوت 🌚💋'
      end
      elseif is_owner(msg.sender_user_id_, msg.chat_id_) then
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'انت مدير الكروب 🌞'
      else
      t = 'انت مدير الكروب 🌞'
      end
      elseif is_mod(msg.sender_user_id_, msg.chat_id_) then
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'انت ادمن الكروب 🔥'
      else
      t = 'انت ادمن الكروب 🔥'
      end
      else
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'انت عضو مقدس 😻👅'
      else
      t = 'انت عضو مقدس 😻👅'
      end
    end
    if result.username_ then
    result.username_ = '@'..result.username_
      else
    result.username_ = 'Not Found'
        end
    if result.last_name_ then
    lastname = result.last_name_
       else
    lastname = 'Not Found'
     end
    if database:get('lang:gp:'..msg.chat_id_) then
send(msg.chat_id_, msg.id_, 1, "\n  "..t.."\n ", 1, 'rrr') 
else
send(msg.chat_id_, msg.id_, 1, "\n  "..t.."\n ", 1, 'rrr')
end
    end
          getUser(msg.sender_user_id_,get_me)
  end

if database:get('bot:cmds'..msg.chat_id_) and not is_mod(msg.sender_user_id_, msg.chat_id_) then
  return 
else
  
if text == 'هلو' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'هلاا ⁽ نـورت حـيـآتـي 😻🌸 ⁾'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end

if text == 'هاي' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'هلاا ⁽ نـورت حـيـآتـي 😻🌸 ⁾'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'هلاو' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'هلاا ⁽ نـورت حـيـآتـي 😻🌸 ⁾'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'مرحبا' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'هلاا ⁽ نـورت حـيـآتـي 😻🌸 ⁾'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'هلا' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'هلاا ⁽ نـورت حـيـآتـي 😻🌸 ⁾'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'كوكي' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'يـآ بـعد رووح كـؤكـي 🌝👅\nمـشـتـغـل والـلـه 🤖🤘'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'شلونكم' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'تمام ونت ❥🐚💛 '
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'شلونك' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'تمام ونت  ❥ 🌎🌸'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'تمام' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'دۈۋم يّےـآٱآرب ↜┇✥ 💁🏿‍♂️👅 '
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == '😐' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = ' ﺸبﯿك صۜافن ؏ خالتك😹🙇🏻❤️ '
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'اريد اكبل' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'شـًٍـًٍوــًٍـًٍفـًٍــًٍـًٍلـًٍلًٍي وياك حديقه ودايح رسمي 🙇🏿💜😹'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'لتزحف' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'دعوفه زاحف ع خالتك خلي يستفاد😕😹🙊'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'كلخرا' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'خرا ليترس حلكك/ج ياخرا يابنلخرا خختفووو ابلع😸🙊💋'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'زاحف' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'زاحف ع اختك؟ كضيت عمرك جرجف🌝😹😹🌝كضيت عمرك زحف تره'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'دي' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'يمشوك بيها  🌝💔'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'فرخ' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'وينه خلي احصره ؟🙊😹'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'تعالي خاص' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'اهوو ضل ضل ساحف كبر طمك😔😹❤️'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'اكرهك' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'ديله شلون اطيق خلقتك اني😾🖖🏿🕷'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'احبك' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'פـبـ⚘ـيبي 💓💧 وني هم😻🦀'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'باي' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'وين مولي خلينه متونسين ֆᵛ͢ᵎᵖ ⌯﴾❥ 🐰💔'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'واكف' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'بنلخرا وين واكف😐🏃'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'وين المدير' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'ڸـﯿﺸ شتريد🙄💔🍃'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'انجب' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = ' ع وجهك / ج 🐸🍃'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'تحبني' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'مادري افڱﮩﮩﮩر🐸💔'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == '🌚' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'ڤڍ  ﯿت ڝخٲﻣك😻🕷👄'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == '🙄' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = '؏ينڱ نژله اﺨاف عليك/ﭻ 🙇🏻💚'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == '😒' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'شــبيگ •┇✞🐤💦 حـٰ« ࿐❥ـبي 🐹'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == '😳' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'ها بس لا شفت خالتك الشكره 😳😹🕷'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == '🙁' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'تعال اشكيلي اهمومك ليش ضايج 🙁😭💔'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == '🚶💔' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'تعال اشكيلي اهمومك ليش ضايج 🙁😭💔'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == '🙂' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'ثكيل علساس هه😪🌞'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == '🌝' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'مٰ̲ہٰٰنہٰٰوِٰڕٰ حہٰٰبྀ̲ہ؏ۤـٖٓہٰٰمٰ̲ہٰٰڕٰيِٰہٰٰ┊※🌝️‘’💛'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'كفو' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'الاه كفو يبو لضلوع اه 😻😹'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == '😌' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'المطلوب ؟'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'اها' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'يب قابل اغشك شسالفة ضلع 😐🌝🎧'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'منو ديحذف رسائلي' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'محد 😐🍃'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'البوت واكف' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'لتجذب 😒'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'غلس' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'اعمل حالك/ج😴 ميت'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'وين' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'بأرض الله الواسعـة🙄'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'نايمين' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'اني سهران احرسكـم😐🍃'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'اكو احد' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'يي عيني انـي موجـود🌝🌿'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'فديت' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'فداكـ/چ ثولان العالـم😍😂'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'شكو' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'كلشي وكلاشي🐸تگـول عبالك احنـة بالشورجـة🌝'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'اوف' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'سلامتـكـ/چ من الأووف يـا بعد افادي☹️💔'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'احبج' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'واليحب بلوة🙄وين الله وزحفتي تجيبلي عيونچ الحلـوة🙄🤓'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
if text == 'انتة منو' then 
if not database:get('bot:rep:mute'..msg.chat_id_) then
moody = 'آني كـامل مفيد اكبر زنگين أگعدة عالحديـد😼🙌'
else 
moody = ''
end
send(msg.chat_id_, msg.id_, 1, moody, 1, 'md')
end
end
  -----------------------------------------------------------------------------------------------
 end
  -----------------------------------------------------------------------------------------------
                                       -- end code --
  -----------------------------------------------------------------------------------------------
  elseif (data.ID == "UpdateChat") then
    chat = data.chat_
    chats[chat.id_] = chat
  -----------------------------------------------------------------------------------------------
  elseif (data.ID == "UpdateMessageEdited") then
   local msg = data
  -- vardump(msg)
  	function get_msg_contact(extra, result, success)
	local text = (result.content_.text_ or result.content_.caption_)
    --vardump(result)
	if result.id_ and result.content_.text_ then
	database:set('bot:editid'..result.id_,result.content_.text_)
	end
  if not is_mod(result.sender_user_id_, result.chat_id_) then
   check_filter_words(result, text)
   if text:match("[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm].[Mm][Ee]") or
text:match("[Tt].[Mm][Ee]") or text:match("[Tt][Ll][Gg][Rr][Mm].[Mm][Ee]") then
   if database:get('bot:links:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end

   if text:match("[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm].[Mm][Ee]") or
text:match("[Tt].[Mm][Ee]") or text:match("[Tt][Ll][Gg][Rr][Mm].[Mm][Ee]") then
   if database:get('bot:links:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
       send(msg.chat_id_, 0, 1, "<code>ممنوع عمل تعديل بالروابط </b>\n", 1, 'html')
	end
end
end

   	if text:match("[Hh][Tt][Tt][Pp][Ss]://") or text:match("[Hh][Tt][Tt][Pp]://") or text:match(".[Ii][Rr]") or text:match(".[Cc][Oo][Mm]") or text:match(".[Oo][Rr][Gg]") or text:match(".[Ii][Nn][Ff][Oo]") or text:match("[Ww][Ww][Ww].") or text:match(".[Tt][Kk]") then
   if database:get('bot:webpage:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end
	
   if database:get('bot:webpage:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
       send(msg.chat_id_, 0, 1, "<code>ممنوع عمل تعديل للمواقع</code>\n", 1, 'html')
	end
end
end
   if text:match("@") then
   if database:get('bot:tag:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end
	   if database:get('bot:tag:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
       send(msg.chat_id_, 0, 1, "<code>ممنوع عمل تعديل للمعرفات</code>\n", 1, 'html')
	end
   	if text:match("#") then
   if database:get('bot:hashtag:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end
	   if database:get('bot:hashtag:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
       send(msg.chat_id_, 0, 1, "<code>ممنوع عمل تعديل للتاكات</code>\n", 1, 'html')
	end
   	if text:match("/") then
   if database:get('bot:cmd:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end
	   if database:get('bot:cmd:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
       send(msg.chat_id_, 0, 1, "<code>ممنوع عمل تعديل للشارحه</code>\n", 1, 'html')
	end
end
   	if text:match("[\216-\219][\128-\191]") then
   if database:get('bot:arabic:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end
	end
	   if database:get('bot:arabic:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
              send(msg.chat_id_, 0, 1, "<code>ممنوع عمل تعديل للغه العربيه</code>\n", 1, 'html')
	end
   end
   if text:match("[ASDFGHJKLQWERTYUIOPZXCVBNMasdfghjklqwertyuiopzxcvbnm]") then
   if database:get('bot:english:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end
	   if database:get('bot:english:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
              send(msg.chat_id_, 0, 1, "<code>ممنوع عمل تعديل  للغه الانكليزيه</code>\n", 1, 'html')
end
end
    end
	end
	if database:get('editmsg'..msg.chat_id_) == 'delmsg' then
        local id = msg.message_id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
              delete_msg(chat,msgs)
                            send(msg.chat_id_, 0, 1, "`📌¦ `_ممنوع عمل تعديل هنا 🌚👅_", 1, 'md')
	elseif database:get('editmsg'..msg.chat_id_) == 'didam' then
	if database:get('bot:editid'..msg.message_id_) then
		local old_text = database:get('bot:editid'..msg.message_id_)
     send(msg.chat_id_, msg.message_id_, 1, '`لقد قمت بالتعديل\n\nرسالتك السابقه :`\n\n`[ '..old_text..' ]`', 1, 'md')
	end
end

    getMessage(msg.chat_id_, msg.message_id_,get_msg_contact)
  -----------------------------------------------------------------------------------------------
  elseif (data.ID == "UpdateOption" and data.name_ == "my_id") then
    tdcli_function ({ID="GetChats", offset_order_="9223372036854775807", offset_chat_id_=0, limit_=20}, dl_cb, nil)    
  end
  -----------------------------------------------------------------------------------------------
end

--[[                                -.-

--]]
