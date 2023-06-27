%% Copyright (c) 2010 Jacob Vorreuter <jacob.vorreuter@gmail.com>
%%
%% Permission is hereby granted, free of charge, to any person
%% obtaining a copy of this software and associated documentation
%% files (the "Software"), to deal in the Software without
%% restriction, including without limitation the rights to use,
%% copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following
%% conditions:
%%
%% The above copyright notice and this permission notice shall be
%% included in all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
%% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
%% OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
%% NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
%% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
%% WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
%% OTHER DEALINGS IN THE SOFTWARE.

%% syslog rfc: http://www.faqs.org/rfcs/rfc3164.html

-module(syslog).
-behaviour(gen_server).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2, code_change/3]).

%% api callbacks
-export([start_link/0, start_link/1,
         send/1, send/2, send/3]).

-record(state, {socket, address, port, facility, app_name,host}).

-define(DEFAULT_FACILITY, local0).

%%====================================================================
%% api callbacks
%%====================================================================
start_link() ->
    {ok, Host} = inet:gethostname(),
    gen_server:start_link({local, ?MODULE}, ?MODULE, [?MODULE, Host, 514, ?DEFAULT_FACILITY], []).

start_link(Name) when is_atom(Name) ->
    {ok, Host} = inet:gethostname(),
    gen_server:start_link({local, Name},  ?MODULE, [Name, Host, 514, ?DEFAULT_FACILITY], []).

%% start_link(Name, Host, Port) when is_atom(Name), is_list(Host), is_integer(Port) ->
%%     gen_server:start_link({local, Name}, ?MODULE, [?MODULE, Host, Port, ?DEFAULT_FACILITY], []).
%% 
%% start_link(Name, Host, Port, Facility) when is_atom(Name), is_list(Host),
%%                                            is_integer(Port), is_atom(Facility) ->
%%     gen_server:start_link({local, Name}, ?MODULE, [?MODULE, Host, Port, Facility], []).
%% 
%% start_link(Name, AppName, Host, Port, Facility) when is_atom(Name), is_atom(AppName), is_list(Host),
%%                                                  is_integer(Port), is_atom(Facility) ->
%%     gen_server:start_link({local, Name}, ?MODULE, [AppName, Host, Port, Facility], []).

send(Msg) ->
    gen_server:call(name,{send,Msg}).

send(Msg, Opts) when is_list(Msg), is_list(Opts) ->
    send(?MODULE, Msg, []);

send(Name, Msg) when is_list(Msg) ->
    send(Name, Msg, []).

send(Name, Msg, Opts) when is_list(Msg), is_list(Opts) ->
%% 	Packet = build_packet(Name, Msg, Opts),
%% 	io:format("~p~n", [Msg]),
%% sync
%%     gen_server:call(Name, {send, Msg}).
%% async
	gen_server:cast(Name, {send, Msg}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
%%--------------------------------------------------------------------
init([AppName, Host, Port, Facility]) ->
%%     {ok, Addr} = inet:getaddr(Host, inet),
%% 	{ok, Addr} = gen_udp:open(0, [{active, false},{ifaddr, {local,"/dev/log"}}]),
%%     case gen_udp:open(0) of
%% 	io:format("~p~n", [AppName]),
	case gen_udp:open(0, [local,{active, true},{buffer,1024000},{broadcast,false},{dontroute, false},{low_msgq_watermark, 819200},{high_msgq_watermark, 981920}]) of
        {ok, Socket} ->
            {ok, #state{
                    socket = Socket,
                    port = Port,
                    facility = Facility,
                    app_name = AppName,
					host = Host
            }};
        {error, Reason} ->
            {stop, Reason}
    end.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%%--------------------------------------------------------------------
handle_call(facility, _From, #state{facility=Facility}=State) ->
	io:format("facility"),
    {reply, Facility, State};
handle_call(app_name,  _From, #state{app_name=AppName}=State) ->
	io:format("app_name"),
    {reply, AppName, State};
handle_call({send,Msg},_From, #state{socket=Socket,facility = Facility,app_name=AppName}=State) ->
	%%debug
%% 		io:format("~p~p~p~p~n", [Msg,Socket,State,?MODULE]),
    Packet = build_packet(?MODULE, Msg, [{facility,Facility},{app_name,AppName}]),
%% 		io:format("~p~n", [Msg]),
%% 		io:format("~p~n", [Packet]),
	gen_udp:send(Socket, {local, <<"/dev/log">>}, 0, Packet),
    {reply, ok,State}.

%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%%--------------------------------------------------------------------
handle_cast({send, Msg},#state{socket=Socket,app_name=AppName}=State) ->
	%%debug
%% 		io:format("~p~n", [Facility]),
%%     Packet = build_packet(?MODULE, Msg, [{facility,Facility},{app_name,AppName}]),
%%     Pid = os:getpid(),
    Level =  integer_to_list(6),
	Packet = [
              "<", Level, ">", % syslog version 1
              atom_to_list(AppName), ":",
              Msg
             ],
    iolist_to_binary(Packet),
	gen_udp:send(Socket, {local, <<"/dev/log">>}, 0, Packet),
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
get_level(Facility, Opts) ->
    Level = atom_to_level(proplists:get_value(level, Opts)),
    integer_to_list((Facility * 8) + Level).

get_app_name(Name) ->
    case gen_server:call(Name, app_name) of
        Atom when is_atom(Atom) -> atom_to_list(Atom);
        List when is_list(List) -> List;
        Binary when is_binary(Binary) -> Binary;
		_ -> io:format("default_name")
    end.

get_app_name(Name, Opts) ->
    case proplists:get_value(app_name, Opts) of
        undefined -> get_app_name(Name);
        Atom when is_atom(Atom) -> atom_to_list(Atom);
        List when is_list(List) -> List;
        Binary when is_binary(Binary) -> Binary
    end.

get_pid(Opts) ->
    case proplists:get_value(pid, Opts) of
        undefined -> os:getpid();
        Atom when is_atom(Atom) -> atom_to_list(Atom);
        List when is_list(List) -> List;
        Binary when is_binary(Binary) -> Binary
    end.

get_facility(Name) ->
    Facility = gen_server:call(Name, facility),
    facility(Facility).

get_facility(Name, Opts) ->
    case proplists:get_value(facility, Opts) of
        undefined -> get_facility(Name);
        Facility when is_atom(Facility) -> facility(Facility);
        Facility when is_integer(Facility) -> Facility
    end.

get_hostname(Opts) ->
    case proplists:get_value(hostname, Opts) of
        undefined ->
            {ok, Host} = inet:gethostname(),
            Host;
        Atom when is_atom(Atom) -> atom_to_list(Atom);
        List when is_list(List) -> List;
        Binary when is_binary(Binary) -> Binary
    end.

get_timestamp(Opts) when is_list(Opts) ->
    case proplists:get_value(timestamp, Opts) of
        undefined -> format_timestamp(os:timestamp());
        Timestamp -> format_timestamp(Timestamp)
    end.

format_timestamp(TS) ->
    {{Y, M, D}, {H, MM, S}} = calendar:now_to_universal_time(TS),
    US = element(3, TS),
    io_lib:format("~4.10.0B-~2.10.0B-~2.10.0BT~2.10.0B:~2.10.0B:~2.10.0B.~6.10.0BZ",
                  [Y,M,D, H,MM,S,US]).

build_packet(Name, Msg, Opts) ->
    AppName = get_app_name(Name, Opts),
%% 	io:format("~p~n",[AppName]),
    Pid = get_pid(Opts),
%% 	io:format("~p~n",[Pid]),
    Hostname = get_hostname(Opts),
%% 	io:format("~p~n",[Hostname]),
    Timestamp = get_timestamp(Opts),
%% 	io:format("~p~n",[Timestamp]),
    Facility = get_facility(Name, Opts),
%% 	io:format("~p~n",[Facility]),
    Level = get_level(Facility, Opts),
%% 	io:format("~p~n",[Level]),
    Packet = [
              "<", Level, ">1 ", % syslog version 1
              Timestamp, " ",
              Hostname, " ",
              AppName, " ",
              Pid,
              " - - ", % MSGID is -, STRUCTURED-DATA is -
              Msg, "\n"
             ],
%% 	io:format("~p~n",[Packet]),
    iolist_to_binary(Packet).

atom_to_level(emergency) -> 0; % system is unusable
atom_to_level(alert) -> 1; % action must be taken immediately
atom_to_level(critical) -> 2; % critical conditions
atom_to_level(error) -> 3; % error conditions
atom_to_level(warning) -> 4; % warning conditions
atom_to_level(notice) -> 5; % normal but significant condition
atom_to_level(info) -> 6; % informational
atom_to_level(debug) -> 7; % debug-level messages
atom_to_level(_) -> atom_to_level(info). % default to info

% paraphrased from https://github.com/ngerakines/syslognif/blob/master/src/syslog.erl#L55
facility(kern) -> 0;      % kernel messages
facility(user) -> 1;      % random user-level messages
facility(mail) -> 2;      % mail system
facility(daemon) -> 3;    % system daemons
facility(auth) -> 4;      % security/authorization messages
facility(syslog) -> 5;    % messages generated internally by syslogd
facility(lpr) -> 6;       % line printer subsystem
facility(news) -> 7;      % network news subsystem
facility(uucp) -> 8;      % UUCP subsystem
facility(cron) -> 9;      % clock daemon
facility(authpriv) -> 10; % security/authorization messages (private)
facility(ftp) -> 11;      % ftp daemon

facility(local0) -> 16;   % reserved for local use
facility(local1) -> 17;   % reserved for local use
facility(local2) -> 18;   % reserved for local use
facility(local3) -> 19;   % reserved for local use
facility(local4) -> 20;   % reserved for local use
facility(local5) -> 21;   % reserved for local use
facility(local6) -> 22;   % reserved for local use
facility(local7) -> 23.   % reserved for local use
