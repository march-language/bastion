; March compiler output
target triple = "arm64-apple-macosx15.0.0"

; Runtime declarations
declare ptr  @march_alloc(i64 %sz)
declare void @march_incrc(ptr %p)
declare void @march_decrc(ptr %p)
declare i64  @march_decrc_freed(ptr %p)
declare void @march_incrc_local(ptr %p)
declare void @march_decrc_local(ptr %p)
declare void @march_free(ptr %p)
declare void @march_print(ptr %s)
declare void @march_panic(ptr %s)
declare void @march_println(ptr %s)
declare ptr  @march_string_lit(ptr %s, i64 %len)
declare ptr  @march_int_to_string(i64 %n)
declare ptr  @march_float_to_string(double %f)
declare ptr  @march_bool_to_string(i64 %b)
declare ptr  @march_string_concat(ptr %a, ptr %b)
declare i64  @march_string_eq(ptr %a, ptr %b)
; Ord / Hash builtins
declare i64    @march_compare_int(i64 %x, i64 %y)
declare i64    @march_compare_float(double %x, double %y)
declare i64    @march_compare_string(ptr %x, ptr %y)
declare i64    @march_hash_int(i64 %x)
declare i64    @march_hash_float(double %x)
declare i64    @march_hash_string(ptr %x)
declare i64    @march_hash_bool(i64 %x)
declare i64  @march_string_byte_length(ptr %s)
declare i64  @march_string_is_empty(ptr %s)
declare ptr  @march_string_to_int(ptr %s)
declare ptr  @march_string_join(ptr %list, ptr %sep)
; Float builtins
declare double @march_float_abs(double %f)
declare i64    @march_float_ceil(double %f)
declare i64    @march_float_floor(double %f)
declare i64    @march_float_round(double %f)
declare i64    @march_float_truncate(double %f)
declare double @march_int_to_float(i64 %n)
; Math builtins
declare double @march_math_sin(double %f)
declare double @march_math_cos(double %f)
declare double @march_math_tan(double %f)
declare double @march_math_asin(double %f)
declare double @march_math_acos(double %f)
declare double @march_math_atan(double %f)
declare double @march_math_atan2(double %y, double %x)
declare double @march_math_sinh(double %f)
declare double @march_math_cosh(double %f)
declare double @march_math_tanh(double %f)
declare double @march_math_sqrt(double %f)
declare double @march_math_cbrt(double %f)
declare double @march_math_exp(double %f)
declare double @march_math_exp2(double %f)
declare double @march_math_log(double %f)
declare double @march_math_log2(double %f)
declare double @march_math_log10(double %f)
declare double @march_math_pow(double %b, double %e)
; Extended string builtins
declare i64  @march_string_contains(ptr %s, ptr %sub)
declare i64  @march_string_starts_with(ptr %s, ptr %prefix)
declare i64  @march_string_ends_with(ptr %s, ptr %suffix)
declare ptr  @march_string_slice(ptr %s, i64 %start, i64 %len)
declare ptr  @march_string_split(ptr %s, ptr %sep)
declare ptr  @march_string_split_first(ptr %s, ptr %sep)
declare ptr  @march_string_replace(ptr %s, ptr %old, ptr %new)
declare ptr  @march_string_replace_all(ptr %s, ptr %old, ptr %new)
declare ptr  @march_string_to_lowercase(ptr %s)
declare ptr  @march_string_to_uppercase(ptr %s)
declare ptr  @march_string_trim(ptr %s)
declare ptr  @march_string_trim_start(ptr %s)
declare ptr  @march_string_trim_end(ptr %s)
declare ptr  @march_string_repeat(ptr %s, i64 %n)
declare ptr  @march_string_reverse(ptr %s)
declare ptr  @march_string_pad_left(ptr %s, i64 %width, ptr %fill)
declare ptr  @march_string_pad_right(ptr %s, i64 %width, ptr %fill)
declare i64  @march_string_grapheme_count(ptr %s)
declare ptr  @march_string_index_of(ptr %s, ptr %sub)
declare ptr  @march_string_last_index_of(ptr %s, ptr %sub)
declare ptr  @march_string_to_float(ptr %s)
; List builtins
declare ptr  @march_list_append(ptr %a, ptr %b)
declare ptr  @march_list_concat(ptr %lists)
; LLVM intrinsics
declare i64  @llvm.ctpop.i64(i64 %val)

; Actor builtins
declare void @march_kill(ptr %actor)
declare i64  @march_is_alive(ptr %actor)
declare ptr  @march_send(ptr %actor, ptr %msg)
declare ptr  @march_send_linear(ptr %actor, ptr %msg)
declare ptr  @march_msg_copy(ptr %src_heap, ptr %dst_heap, ptr %value)
declare ptr  @march_msg_move(ptr %src_heap, ptr %dst_heap, ptr %value)
declare ptr  @march_process_alloc(ptr %heap, i64 %sz)
declare ptr  @march_spawn(ptr %actor)
declare i64  @march_actor_get_int(ptr %actor, i64 %index)
declare void @march_run_scheduler()
@march_tls_reductions = external thread_local global i64
declare void @march_yield_from_compiled()
; TCP/network builtins
declare i64  @march_tcp_listen(i64 %port)
declare i64  @march_tcp_accept(i64 %fd)
declare ptr  @march_tcp_recv_http(i64 %fd, i64 %max)
declare void @march_tcp_send_all(i64 %fd, ptr %data)
declare void @march_tcp_close(i64 %fd)
declare ptr  @march_http_parse_request(ptr %raw)
declare ptr  @march_http_serialize_response(i64 %status, ptr %headers, ptr %body)
declare void @march_http_server_listen(i64 %port, i64 %max_conns, i64 %idle_timeout, ptr %pipeline)
declare void @march_ws_handshake(i64 %fd, ptr %key)
declare ptr  @march_ws_recv(i64 %fd)
declare void @march_ws_send(i64 %fd, ptr %frame)
declare ptr  @march_ws_select(i64 %fd, ptr %pipe, i64 %timeout)
; File/Dir builtins
declare i64  @march_file_exists(ptr %s)
declare i64  @march_dir_exists(ptr %s)
declare ptr  @march_file_open(ptr %path)
declare ptr  @march_file_close(ptr %handle)
declare ptr  @march_file_read(ptr %path)
declare ptr  @march_file_read_line(ptr %handle)
declare ptr  @march_file_read_chunk(ptr %handle, i64 %size)
declare ptr  @march_file_write(ptr %path, ptr %data)
declare ptr  @march_file_append(ptr %path, ptr %data)
declare ptr  @march_file_delete(ptr %path)
declare ptr  @march_file_copy(ptr %src, ptr %dst)
declare ptr  @march_file_rename(ptr %src, ptr %dst)
declare ptr  @march_file_stat(ptr %path)
declare ptr  @march_dir_mkdir(ptr %path)
declare ptr  @march_dir_mkdir_p(ptr %path)
declare ptr  @march_dir_rmdir(ptr %path)
declare ptr  @march_dir_rm_rf(ptr %path)
declare ptr  @march_dir_list(ptr %path)
declare ptr  @march_dir_list_full(ptr %path)
declare ptr  @march_process_argv()
declare ptr  @march_tcp_connect(ptr %host, i64 %port)
; HTTP client builtins
declare ptr  @march_http_serialize_request(ptr %method, ptr %host, ptr %path, ptr %query, ptr %headers, ptr %body)
declare ptr  @march_http_parse_response(ptr %raw)
; CSV builtins
declare ptr  @march_csv_open(ptr %path, ptr %delim, ptr %mode)
declare ptr  @march_csv_next_row(ptr %handle)
declare ptr  @march_csv_close(ptr %handle)
; Resource ownership
declare void @march_own(ptr %pid, ptr %value)
; Capability builtins
declare ptr  @march_cap_narrow(ptr %cap)
; Monitor/supervision builtins
declare void @march_demonitor(i64 %ref)
declare i64  @march_monitor(ptr %watcher, ptr %target)
declare i64  @march_mailbox_size(ptr %pid)
declare void @march_run_until_idle()
declare void @march_register_resource(ptr %pid, ptr %name, ptr %cleanup)
declare ptr  @march_get_cap(ptr %pid)
declare void @march_send_checked(ptr %cap, ptr %msg)
declare ptr  @march_pid_of_int(i64 %n)
declare ptr  @march_get_actor_field(ptr %pid, ptr %name)
declare void @march_link(ptr %actor_a, ptr %actor_b)
declare void @march_unlink(ptr %actor_a, ptr %actor_b)
declare void @march_register_supervisor(ptr %supervisor, i64 %strategy, i64 %max_restarts, i64 %window_secs)
declare ptr  @march_value_to_string(ptr %v)
@.str1 = private unnamed_addr constant [4 x i8] c"new\00"
@.str2 = private unnamed_addr constant [54 x i8] c"error: missing app name\0Ausage: bastion new <app_name>\00"
@.str3 = private unnamed_addr constant [25 x i8] c"error: unknown command: \00"
@.str4 = private unnamed_addr constant [30 x i8] c"Bastion \E2\80\94 web framework CLI\00"
@.str5 = private unnamed_addr constant [1 x i8] c"\00"
@.str6 = private unnamed_addr constant [10 x i8] c"Commands:\00"
@.str7 = private unnamed_addr constant [60 x i8] c"  bastion new <app_name>   Create a new Bastion application\00"
@.str8 = private unnamed_addr constant [19 x i8] c"error: directory '\00"
@.str9 = private unnamed_addr constant [17 x i8] c"' already exists\00"
@.str10 = private unnamed_addr constant [23 x i8] c"Creating Bastion app: \00"
@.str11 = private unnamed_addr constant [1 x i8] c"\00"
@.str12 = private unnamed_addr constant [18 x i8] c"Done! Next steps:\00"
@.str13 = private unnamed_addr constant [1 x i8] c"\00"
@.str14 = private unnamed_addr constant [6 x i8] c"  cd \00"
@.str15 = private unnamed_addr constant [13 x i8] c"  forge deps\00"
@.str16 = private unnamed_addr constant [12 x i8] c"  forge run\00"
@.str17 = private unnamed_addr constant [1 x i8] c"\00"
@.str18 = private unnamed_addr constant [42 x i8] c"Your app will be at http://localhost:4000\00"
@.str19 = private unnamed_addr constant [5 x i8] c"/lib\00"
@.str20 = private unnamed_addr constant [8 x i8] c"/public\00"
@.str21 = private unnamed_addr constant [12 x i8] c"/public/css\00"
@.str22 = private unnamed_addr constant [11 x i8] c"/public/js\00"
@.str23 = private unnamed_addr constant [9 x i8] c"/islands\00"
@.str24 = private unnamed_addr constant [6 x i8] c"/test\00"
@.str25 = private unnamed_addr constant [12 x i8] c"/forge.toml\00"
@.str26 = private unnamed_addr constant [15 x i8] c"/.editorconfig\00"
@.str27 = private unnamed_addr constant [12 x i8] c"/.gitignore\00"
@.str28 = private unnamed_addr constant [11 x i8] c"/README.md\00"
@.str29 = private unnamed_addr constant [6 x i8] c"/lib/\00"
@.str30 = private unnamed_addr constant [7 x i8] c".march\00"
@.str31 = private unnamed_addr constant [27 x i8] c"/lib/page_controller.march\00"
@.str32 = private unnamed_addr constant [19 x i8] c"/lib/counter.march\00"
@.str33 = private unnamed_addr constant [20 x i8] c"/public/css/app.css\00"
@.str34 = private unnamed_addr constant [20 x i8] c"/public/js/.gitkeep\00"
@.str35 = private unnamed_addr constant [1 x i8] c"\00"
@.str36 = private unnamed_addr constant [18 x i8] c"/islands/.gitkeep\00"
@.str37 = private unnamed_addr constant [1 x i8] c"\00"
@.str38 = private unnamed_addr constant [7 x i8] c"/test/\00"
@.str39 = private unnamed_addr constant [12 x i8] c"_test.march\00"
@.str40 = private unnamed_addr constant [11 x i8] c"  created \00"
@.str41 = private unnamed_addr constant [2 x i8] c"/\00"
@.str42 = private unnamed_addr constant [11 x i8] c"  created \00"
@.str43 = private unnamed_addr constant [2 x i8] c"_\00"
@.str44 = private unnamed_addr constant [1 x i8] c"\00"
@.str45 = private unnamed_addr constant [11 x i8] c"[package]\0A\00"
@.str46 = private unnamed_addr constant [9 x i8] c"name = \22\00"
@.str47 = private unnamed_addr constant [3 x i8] c"\22\0A\00"
@.str48 = private unnamed_addr constant [19 x i8] c"version = \220.1.0\22\0A\00"
@.str49 = private unnamed_addr constant [14 x i8] c"type = \22app\22\0A\00"
@.str50 = private unnamed_addr constant [18 x i8] c"description = \22\22\0A\00"
@.str51 = private unnamed_addr constant [13 x i8] c"author = \22\22\0A\00"
@.str52 = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str53 = private unnamed_addr constant [8 x i8] c"[deps]\0A\00"
@.str54 = private unnamed_addr constant [35 x i8] c"bastion = { path = \22../bastion\22 }\0A\00"
@.str55 = private unnamed_addr constant [35 x i8] c"islands = { path = \22../islands\22 }\0A\00"
@.str56 = private unnamed_addr constant [14 x i8] c"root = true\0A\0A\00"
@.str57 = private unnamed_addr constant [5 x i8] c"[*]\0A\00"
@.str58 = private unnamed_addr constant [22 x i8] c"indent_style = space\0A\00"
@.str59 = private unnamed_addr constant [17 x i8] c"indent_size = 2\0A\00"
@.str60 = private unnamed_addr constant [17 x i8] c"charset = utf-8\0A\00"
@.str61 = private unnamed_addr constant [18 x i8] c"end_of_line = lf\0A\00"
@.str62 = private unnamed_addr constant [33 x i8] c"trim_trailing_whitespace = true\0A\00"
@.str63 = private unnamed_addr constant [30 x i8] c"insert_final_newline = true\0A\0A\00"
@.str64 = private unnamed_addr constant [11 x i8] c"[*.march]\0A\00"
@.str65 = private unnamed_addr constant [22 x i8] c"indent_style = space\0A\00"
@.str66 = private unnamed_addr constant [17 x i8] c"indent_size = 2\0A\00"
@.str67 = private unnamed_addr constant [10 x i8] c"/.march/\0A\00"
@.str68 = private unnamed_addr constant [17 x i8] c"/islands/*.wasm\0A\00"
@.str69 = private unnamed_addr constant [20 x i8] c"/islands/*.glue.js\0A\00"
@.str70 = private unnamed_addr constant [3 x i8] c"# \00"
@.str71 = private unnamed_addr constant [3 x i8] c"\0A\0A\00"
@.str72 = private unnamed_addr constant [70 x i8] c"A [Bastion](https://github.com/march-lang/bastion) web application.\0A\0A\00"
@.str73 = private unnamed_addr constant [21 x i8] c"## Getting started\0A\0A\00"
@.str74 = private unnamed_addr constant [9 x i8] c"```bash\0A\00"
@.str75 = private unnamed_addr constant [12 x i8] c"forge deps\0A\00"
@.str76 = private unnamed_addr constant [11 x i8] c"forge run\0A\00"
@.str77 = private unnamed_addr constant [6 x i8] c"```\0A\0A\00"
@.str78 = private unnamed_addr constant [30 x i8] c"Visit http://localhost:4000\0A\0A\00"
@.str79 = private unnamed_addr constant [15 x i8] c"## Structure\0A\0A\00"
@.str80 = private unnamed_addr constant [5 x i8] c"```\0A\00"
@.str81 = private unnamed_addr constant [6 x i8] c"lib/\0A\00"
@.str82 = private unnamed_addr constant [3 x i8] c"  \00"
@.str83 = private unnamed_addr constant [49 x i8] c".march          # Router and server entry point\0A\00"
@.str84 = private unnamed_addr constant [42 x i8] c"  page_controller.march  # Page handlers\0A\00"
@.str85 = private unnamed_addr constant [53 x i8] c"  counter.march          # Example island component\0A\00"
@.str86 = private unnamed_addr constant [60 x i8] c"public/                  # Static assets (CSS, JS, images)\0A\00"
@.str87 = private unnamed_addr constant [58 x i8] c"islands/                 # Compiled .wasm island modules\0A\00"
@.str88 = private unnamed_addr constant [34 x i8] c"test/                    # Tests\0A\00"
@.str89 = private unnamed_addr constant [6 x i8] c"```\0A\0A\00"
@.str90 = private unnamed_addr constant [13 x i8] c"## Islands\0A\0A\00"
@.str91 = private unnamed_addr constant [29 x i8] c"Compile an island to WASM:\0A\0A\00"
@.str92 = private unnamed_addr constant [9 x i8] c"```bash\0A\00"
@.str93 = private unnamed_addr constant [91 x i8] c"march --compile --target wasm32-unknown-unknown lib/counter.march -o islands/Counter.wasm\0A\00"
@.str94 = private unnamed_addr constant [5 x i8] c"```\0A\00"
@.str95 = private unnamed_addr constant [5 x i8] c"mod \00"
@.str96 = private unnamed_addr constant [6 x i8] c" do\0A\0A\00"
@.str97 = private unnamed_addr constant [21 x i8] c"  import HttpServer\0A\00"
@.str98 = private unnamed_addr constant [17 x i8] c"  import Router\0A\00"
@.str99 = private unnamed_addr constant [21 x i8] c"  import Middleware\0A\00"
@.str100 = private unnamed_addr constant [26 x i8] c"  import PageController\0A\0A\00"
@.str101 = private unnamed_addr constant [34 x i8] c"  pfn build_router() : Router do\0A\00"
@.str102 = private unnamed_addr constant [18 x i8] c"    Router.new()\0A\00"
@.str103 = private unnamed_addr constant [68 x i8] c"    |> Router.get(\22/\22,       fn conn -> PageController.home(conn))\0A\00"
@.str104 = private unnamed_addr constant [69 x i8] c"    |> Router.get(\22/about\22,  fn conn -> PageController.about(conn))\0A\00"
@.str105 = private unnamed_addr constant [55 x i8] c"    |> Router.get(\22/health\22, fn conn -> health(conn))\0A\00"
@.str106 = private unnamed_addr constant [8 x i8] c"  end\0A\0A\00"
@.str107 = private unnamed_addr constant [37 x i8] c"  pfn health(conn : Conn) : Conn do\0A\00"
@.str108 = private unnamed_addr constant [55 x i8] c"    HttpServer.json(conn, 200, \22{\5C\22status\5C\22:\5C\22ok\5C\22}\22)\0A\00"
@.str109 = private unnamed_addr constant [8 x i8] c"  end\0A\0A\00"
@.str110 = private unnamed_addr constant [23 x i8] c"  fn main() : Unit do\0A\00"
@.str111 = private unnamed_addr constant [34 x i8] c"    let router  = build_router()\0A\00"
@.str112 = private unnamed_addr constant [42 x i8] c"    let plug    = Router.to_plug(router)\0A\00"
@.str113 = private unnamed_addr constant [33 x i8] c"    let wrapped = fn conn -> do\0A\00"
@.str114 = private unnamed_addr constant [29 x i8] c"      let c1 = logger(conn)\0A\00"
@.str115 = private unnamed_addr constant [31 x i8] c"      let c2 = request_id(c1)\0A\00"
@.str116 = private unnamed_addr constant [25 x i8] c"      let c3 = cors(c2)\0A\00"
@.str117 = private unnamed_addr constant [38 x i8] c"      match HttpServer.halted(c3) do\0A\00"
@.str118 = private unnamed_addr constant [19 x i8] c"      true  -> c3\0A\00"
@.str119 = private unnamed_addr constant [25 x i8] c"      false -> plug(c3)\0A\00"
@.str120 = private unnamed_addr constant [11 x i8] c"      end\0A\00"
@.str121 = private unnamed_addr constant [9 x i8] c"    end\0A\00"
@.str122 = private unnamed_addr constant [14 x i8] c"    println(\22\00"
@.str123 = private unnamed_addr constant [39 x i8] c" listening on http://localhost:4000\22)\0A\00"
@.str124 = private unnamed_addr constant [26 x i8] c"    HttpServer.new(4000)\0A\00"
@.str125 = private unnamed_addr constant [33 x i8] c"    |> HttpServer.plug(wrapped)\0A\00"
@.str126 = private unnamed_addr constant [28 x i8] c"    |> HttpServer.listen()\0A\00"
@.str127 = private unnamed_addr constant [8 x i8] c"  end\0A\0A\00"
@.str128 = private unnamed_addr constant [5 x i8] c"end\0A\00"
@.str129 = private unnamed_addr constant [24 x i8] c"mod PageController do\0A\0A\00"
@.str130 = private unnamed_addr constant [22 x i8] c"  import HttpServer\0A\0A\00"
@.str131 = private unnamed_addr constant [34 x i8] c"  fn home(conn : Conn) : Conn do\0A\00"
@.str132 = private unnamed_addr constant [47 x i8] c"    HttpServer.html(conn, 200, layout(\22Home\22,\0A\00"
@.str133 = private unnamed_addr constant [23 x i8] c"      \22<h1>Welcome to \00"
@.str134 = private unnamed_addr constant [14 x i8] c"!</h1>\5Cn\22 ++\0A\00"
@.str135 = private unnamed_addr constant [81 x i8] c"      \22<p>Edit <code>lib/page_controller.march</code> to get started.</p>\5Cn\22 ++\0A\00"
@.str136 = private unnamed_addr constant [45 x i8] c"      \22<p><a href=\5C\22/about\5C\22>About</a></p>\22\0A\00"
@.str137 = private unnamed_addr constant [8 x i8] c"    ))\0A\00"
@.str138 = private unnamed_addr constant [8 x i8] c"  end\0A\0A\00"
@.str139 = private unnamed_addr constant [35 x i8] c"  fn about(conn : Conn) : Conn do\0A\00"
@.str140 = private unnamed_addr constant [48 x i8] c"    HttpServer.html(conn, 200, layout(\22About\22,\0A\00"
@.str141 = private unnamed_addr constant [29 x i8] c"      \22<h1>About</h1>\5Cn\22 ++\0A\00"
@.str142 = private unnamed_addr constant [90 x i8] c"      \22<p>Built with <a href=\5C\22https://github.com/march-lang/bastion\5C\22>Bastion</a>.</p>\22\0A\00"
@.str143 = private unnamed_addr constant [8 x i8] c"    ))\0A\00"
@.str144 = private unnamed_addr constant [8 x i8] c"  end\0A\0A\00"
@.str145 = private unnamed_addr constant [57 x i8] c"  pfn layout(title : String, body : String) : String do\0A\00"
@.str146 = private unnamed_addr constant [28 x i8] c"    \22<!DOCTYPE html>\5Cn\22 ++\0A\00"
@.str147 = private unnamed_addr constant [31 x i8] c"    \22<html lang=\5C\22en\5C\22>\5Cn\22 ++\0A\00"
@.str148 = private unnamed_addr constant [19 x i8] c"    \22<head>\5Cn\22 ++\0A\00"
@.str149 = private unnamed_addr constant [39 x i8] c"    \22  <meta charset=\5C\22utf-8\5C\22>\5Cn\22 ++\0A\00"
@.str150 = private unnamed_addr constant [87 x i8] c"    \22  <meta name=\5C\22viewport\5C\22 content=\5C\22width=device-width, initial-scale=1\5C\22>\5Cn\22 ++\0A\00"
@.str151 = private unnamed_addr constant [34 x i8] c"    \22  <title>\22 ++ title ++ \22 \C2\B7 \00"
@.str152 = private unnamed_addr constant [16 x i8] c"</title>\5Cn\22 ++\0A\00"
@.str153 = private unnamed_addr constant [62 x i8] c"    \22  <link rel=\5C\22stylesheet\5C\22 href=\5C\22/css/app.css\5C\22>\5Cn\22 ++\0A\00"
@.str154 = private unnamed_addr constant [20 x i8] c"    \22</head>\5Cn\22 ++\0A\00"
@.str155 = private unnamed_addr constant [19 x i8] c"    \22<body>\5Cn\22 ++\0A\00"
@.str156 = private unnamed_addr constant [77 x i8] c"    \22  <nav><a href=\5C\22/\5C\22>Home</a> <a href=\5C\22/about\5C\22>About</a></nav>\5Cn\22 ++\0A\00"
@.str157 = private unnamed_addr constant [48 x i8] c"    \22  <main>\5Cn\22 ++ body ++ \22\5Cn  </main>\5Cn\22 ++\0A\00"
@.str158 = private unnamed_addr constant [20 x i8] c"    \22</body>\5Cn\22 ++\0A\00"
@.str159 = private unnamed_addr constant [17 x i8] c"    \22</html>\5Cn\22\0A\00"
@.str160 = private unnamed_addr constant [8 x i8] c"  end\0A\0A\00"
@.str161 = private unnamed_addr constant [5 x i8] c"end\0A\00"
@.str162 = private unnamed_addr constant [42 x i8] c"-- Counter \E2\80\94 example island component.\0A\00"
@.str163 = private unnamed_addr constant [4 x i8] c"--\0A\00"
@.str164 = private unnamed_addr constant [21 x i8] c"-- Compile to WASM:\0A\00"
@.str165 = private unnamed_addr constant [97 x i8] c"--   march --compile --target wasm32-unknown-unknown lib/counter.march -o islands/Counter.wasm\0A\0A\00"
@.str166 = private unnamed_addr constant [17 x i8] c"mod Counter do\0A\0A\00"
@.str167 = private unnamed_addr constant [33 x i8] c"  type State = { count : Int }\0A\0A\00"
@.str168 = private unnamed_addr constant [46 x i8] c"  fn render(state_json : String) : String do\0A\00"
@.str169 = private unnamed_addr constant [41 x i8] c"    let count = parse_count(state_json)\0A\00"
@.str170 = private unnamed_addr constant [36 x i8] c"    \22<div class=\5C\22counter\5C\22>\5Cn\22 ++\0A\00"
@.str171 = private unnamed_addr constant [63 x i8] c"    \22  <button data-on-click=\5C\22Decrement\5C\22>\E2\88\92</button>\5Cn\22 ++\0A\00"
@.str172 = private unnamed_addr constant [74 x i8] c"    \22  <span class=\5C\22count\5C\22>\22 ++ int_to_string(count) ++ \22</span>\5Cn\22 ++\0A\00"
@.str173 = private unnamed_addr constant [61 x i8] c"    \22  <button data-on-click=\5C\22Increment\5C\22>+</button>\5Cn\22 ++\0A\00"
@.str174 = private unnamed_addr constant [14 x i8] c"    \22</div>\22\0A\00"
@.str175 = private unnamed_addr constant [8 x i8] c"  end\0A\0A\00"
@.str176 = private unnamed_addr constant [65 x i8] c"  fn update(state_json : String, msg_json : String) : String do\0A\00"
@.str177 = private unnamed_addr constant [41 x i8] c"    let count = parse_count(state_json)\0A\00"
@.str178 = private unnamed_addr constant [39 x i8] c"    let new_count = match msg_json do\0A\00"
@.str179 = private unnamed_addr constant [36 x i8] c"      \22\5C\22Increment\5C\22\22 -> count + 1\0A\00"
@.str180 = private unnamed_addr constant [36 x i8] c"      \22\5C\22Decrement\5C\22\22 -> count - 1\0A\00"
@.str181 = private unnamed_addr constant [31 x i8] c"      _              -> count\0A\00"
@.str182 = private unnamed_addr constant [11 x i8] c"      end\0A\00"
@.str183 = private unnamed_addr constant [54 x i8] c"    \22{\5C\22count\5C\22:\22 ++ int_to_string(new_count) ++ \22}\22\0A\00"
@.str184 = private unnamed_addr constant [8 x i8] c"  end\0A\0A\00"
@.str185 = private unnamed_addr constant [49 x i8] c"  pfn parse_count(state_json : String) : Int do\0A\00"
@.str186 = private unnamed_addr constant [37 x i8] c"    match Json.parse(state_json) do\0A\00"
@.str187 = private unnamed_addr constant [17 x i8] c"    Ok(v) -> do\0A\00"
@.str188 = private unnamed_addr constant [37 x i8] c"      match Json.get(v, \22count\22) do\0A\00"
@.str189 = private unnamed_addr constant [33 x i8] c"      Some(n) -> json_to_int(n)\0A\00"
@.str190 = private unnamed_addr constant [20 x i8] c"      None    -> 0\0A\00"
@.str191 = private unnamed_addr constant [11 x i8] c"      end\0A\00"
@.str192 = private unnamed_addr constant [9 x i8] c"    end\0A\00"
@.str193 = private unnamed_addr constant [17 x i8] c"    Err(_) -> 0\0A\00"
@.str194 = private unnamed_addr constant [9 x i8] c"    end\0A\00"
@.str195 = private unnamed_addr constant [8 x i8] c"  end\0A\0A\00"
@.str196 = private unnamed_addr constant [43 x i8] c"  pfn json_to_int(v : JsonValue) : Int do\0A\00"
@.str197 = private unnamed_addr constant [16 x i8] c"    match v do\0A\00"
@.str198 = private unnamed_addr constant [34 x i8] c"    Number(f) -> float_to_int(f)\0A\00"
@.str199 = private unnamed_addr constant [20 x i8] c"    _         -> 0\0A\00"
@.str200 = private unnamed_addr constant [9 x i8] c"    end\0A\00"
@.str201 = private unnamed_addr constant [8 x i8] c"  end\0A\0A\00"
@.str202 = private unnamed_addr constant [5 x i8] c"end\0A\00"
@.str203 = private unnamed_addr constant [53 x i8] c"*, *::before, *::after { box-sizing: border-box; }\0A\0A\00"
@.str204 = private unnamed_addr constant [8 x i8] c"body {\0A\00"
@.str205 = private unnamed_addr constant [39 x i8] c"  font-family: system-ui, sans-serif;\0A\00"
@.str206 = private unnamed_addr constant [21 x i8] c"  max-width: 800px;\0A\00"
@.str207 = private unnamed_addr constant [19 x i8] c"  margin: 0 auto;\0A\00"
@.str208 = private unnamed_addr constant [18 x i8] c"  padding: 1rem;\0A\00"
@.str209 = private unnamed_addr constant [19 x i8] c"  color: #1a1a1a;\0A\00"
@.str210 = private unnamed_addr constant [4 x i8] c"}\0A\0A\00"
@.str211 = private unnamed_addr constant [30 x i8] c"nav { margin-bottom: 2rem; }\0A\00"
@.str212 = private unnamed_addr constant [70 x i8] c"nav a { margin-right: 1rem; color: #0070f3; text-decoration: none; }\0A\00"
@.str213 = private unnamed_addr constant [46 x i8] c"nav a:hover { text-decoration: underline; }\0A\0A\00"
@.str214 = private unnamed_addr constant [12 x i8] c".counter {\0A\00"
@.str215 = private unnamed_addr constant [25 x i8] c"  display: inline-flex;\0A\00"
@.str216 = private unnamed_addr constant [24 x i8] c"  align-items: center;\0A\00"
@.str217 = private unnamed_addr constant [17 x i8] c"  gap: 0.75rem;\0A\00"
@.str218 = private unnamed_addr constant [22 x i8] c"  font-size: 1.5rem;\0A\00"
@.str219 = private unnamed_addr constant [4 x i8] c"}\0A\0A\00"
@.str220 = private unnamed_addr constant [19 x i8] c".counter button {\0A\00"
@.str221 = private unnamed_addr constant [22 x i8] c"  font-size: 1.5rem;\0A\00"
@.str222 = private unnamed_addr constant [18 x i8] c"  width: 2.5rem;\0A\00"
@.str223 = private unnamed_addr constant [19 x i8] c"  height: 2.5rem;\0A\00"
@.str224 = private unnamed_addr constant [27 x i8] c"  border: 1px solid #ccc;\0A\00"
@.str225 = private unnamed_addr constant [23 x i8] c"  border-radius: 6px;\0A\00"
@.str226 = private unnamed_addr constant [20 x i8] c"  cursor: pointer;\0A\00"
@.str227 = private unnamed_addr constant [22 x i8] c"  background: white;\0A\00"
@.str228 = private unnamed_addr constant [4 x i8] c"}\0A\0A\00"
@.str229 = private unnamed_addr constant [48 x i8] c".counter button:hover { background: #f0f0f0; }\0A\00"
@.str230 = private unnamed_addr constant [5 x i8] c"mod \00"
@.str231 = private unnamed_addr constant [10 x i8] c"Test do\0A\0A\00"
@.str232 = private unnamed_addr constant [19 x i8] c"  import Counter\0A\0A\00"
@.str233 = private unnamed_addr constant [33 x i8] c"  describe \22Counter island\22 do\0A\0A\00"
@.str234 = private unnamed_addr constant [42 x i8] c"    test \22render shows initial count\22 do\0A\00"
@.str235 = private unnamed_addr constant [50 x i8] c"      let html = Counter.render(\22{\5C\22count\5C\22:0}\22)\0A\00"
@.str236 = private unnamed_addr constant [43 x i8] c"      assert (String.contains(html, \220\22))\0A\00"
@.str237 = private unnamed_addr constant [10 x i8] c"    end\0A\0A\00"
@.str238 = private unnamed_addr constant [41 x i8] c"    test \22increment increases count\22 do\0A\00"
@.str239 = private unnamed_addr constant [67 x i8] c"      let next = Counter.update(\22{\5C\22count\5C\22:5}\22, \22\5C\22Increment\5C\22\22)\0A\00"
@.str240 = private unnamed_addr constant [43 x i8] c"      assert (String.contains(next, \226\22))\0A\00"
@.str241 = private unnamed_addr constant [10 x i8] c"    end\0A\0A\00"
@.str242 = private unnamed_addr constant [41 x i8] c"    test \22decrement decreases count\22 do\0A\00"
@.str243 = private unnamed_addr constant [67 x i8] c"      let next = Counter.update(\22{\5C\22count\5C\22:5}\22, \22\5C\22Decrement\5C\22\22)\0A\00"
@.str244 = private unnamed_addr constant [43 x i8] c"      assert (String.contains(next, \224\22))\0A\00"
@.str245 = private unnamed_addr constant [10 x i8] c"    end\0A\0A\00"
@.str246 = private unnamed_addr constant [8 x i8] c"  end\0A\0A\00"
@.str247 = private unnamed_addr constant [5 x i8] c"end\0A\00"

define void @march_main() {
entry:
  %red1 = load i64, ptr @march_tls_reductions
  %red_dec2 = sub i64 %red1, 1
  store i64 %red_dec2, ptr @march_tls_reductions
  %need_yield3 = icmp sle i64 %red_dec2, 0
  br i1 %need_yield3, label %sched_yield1, label %sched_cont2
sched_yield1:
  call void @march_yield_from_compiled()
  br label %sched_cont2
sched_cont2:
  %cr4 = call ptr @march_process_argv()
  %args.addr = alloca ptr
  store ptr %cr4, ptr %args.addr
  %ld5 = load ptr, ptr %args.addr
  %res_slot6 = alloca ptr
  %tgp7 = getelementptr i8, ptr %ld5, i64 8
  %tag8 = load i32, ptr %tgp7, align 4
  switch i32 %tag8, label %case_default4 [
      i32 1, label %case_br5
  ]
case_br5:
  %fp9 = getelementptr i8, ptr %ld5, i64 16
  %fv10 = load ptr, ptr %fp9, align 8
  %$f7993.addr = alloca ptr
  store ptr %fv10, ptr %$f7993.addr
  %fp11 = getelementptr i8, ptr %ld5, i64 24
  %fv12 = load ptr, ptr %fp11, align 8
  %$f7994.addr = alloca ptr
  store ptr %fv12, ptr %$f7994.addr
  %freed13 = call i64 @march_decrc_freed(ptr %ld5)
  %freed_b14 = icmp ne i64 %freed13, 0
  br i1 %freed_b14, label %br_unique6, label %br_shared7
br_shared7:
  call void @march_incrc(ptr %fv12)
  call void @march_incrc(ptr %fv10)
  br label %br_body8
br_unique6:
  br label %br_body8
br_body8:
  %ld15 = load ptr, ptr %$f7994.addr
  %res_slot16 = alloca ptr
  %tgp17 = getelementptr i8, ptr %ld15, i64 8
  %tag18 = load i32, ptr %tgp17, align 4
  switch i32 %tag18, label %case_default10 [
      i32 1, label %case_br11
  ]
case_br11:
  %fp19 = getelementptr i8, ptr %ld15, i64 16
  %fv20 = load ptr, ptr %fp19, align 8
  %$f7995.addr = alloca ptr
  store ptr %fv20, ptr %$f7995.addr
  %fp21 = getelementptr i8, ptr %ld15, i64 24
  %fv22 = load ptr, ptr %fp21, align 8
  %$f7996.addr = alloca ptr
  store ptr %fv22, ptr %$f7996.addr
  %ld23 = load ptr, ptr %$f7996.addr
  %rest.addr = alloca ptr
  store ptr %ld23, ptr %rest.addr
  %ld24 = load ptr, ptr %$f7995.addr
  %cmd.addr = alloca ptr
  store ptr %ld24, ptr %cmd.addr
  %ld25 = load ptr, ptr %cmd.addr
  %res_slot26 = alloca ptr
  %sl27 = call ptr @march_string_lit(ptr @.str1, i64 3)
  %seq28 = call i64 @march_string_eq(ptr %ld25, ptr %sl27)
  %cmp29 = icmp ne i64 %seq28, 0
  br i1 %cmp29, label %case_br14, label %str_next15
str_next15:
  br label %case_default13
case_br14:
  %ld30 = load ptr, ptr %cmd.addr
  call void @march_decrc_local(ptr %ld30)
  %ld31 = load ptr, ptr %rest.addr
  %res_slot32 = alloca ptr
  %tgp33 = getelementptr i8, ptr %ld31, i64 8
  %tag34 = load i32, ptr %tgp33, align 4
  switch i32 %tag34, label %case_default17 [
      i32 1, label %case_br18
      i32 0, label %case_br19
  ]
case_br18:
  %fp35 = getelementptr i8, ptr %ld31, i64 16
  %fv36 = load ptr, ptr %fp35, align 8
  %$f7990.addr = alloca ptr
  store ptr %fv36, ptr %$f7990.addr
  %fp37 = getelementptr i8, ptr %ld31, i64 24
  %fv38 = load ptr, ptr %fp37, align 8
  %$f7991.addr = alloca ptr
  store ptr %fv38, ptr %$f7991.addr
  %freed39 = call i64 @march_decrc_freed(ptr %ld31)
  %freed_b40 = icmp ne i64 %freed39, 0
  br i1 %freed_b40, label %br_unique20, label %br_shared21
br_shared21:
  call void @march_incrc(ptr %fv38)
  call void @march_incrc(ptr %fv36)
  br label %br_body22
br_unique20:
  br label %br_body22
br_body22:
  %ld41 = load ptr, ptr %$f7990.addr
  %name.addr = alloca ptr
  store ptr %ld41, ptr %name.addr
  %ld42 = load ptr, ptr %name.addr
  call void @cmd_new(ptr %ld42)
  %cv43 = inttoptr i64 0 to ptr
  store ptr %cv43, ptr %res_slot32
  br label %case_merge16
case_br19:
  %ld44 = load ptr, ptr %rest.addr
  call void @march_decrc_local(ptr %ld44)
  %sl45 = call ptr @march_string_lit(ptr @.str2, i64 53)
  call void @march_panic(ptr %sl45)
  %cv46 = inttoptr i64 0 to ptr
  store ptr %cv46, ptr %res_slot32
  br label %case_merge16
case_default17:
  unreachable
case_merge16:
  %case_r47 = load ptr, ptr %res_slot32
  store ptr %case_r47, ptr %res_slot26
  br label %case_merge12
case_default13:
  %sl48 = call ptr @march_string_lit(ptr @.str3, i64 24)
  %ld49 = load ptr, ptr %cmd.addr
  %cr50 = call ptr @march_string_concat(ptr %sl48, ptr %ld49)
  %$t7992.addr = alloca ptr
  store ptr %cr50, ptr %$t7992.addr
  %ld51 = load ptr, ptr %$t7992.addr
  call void @march_panic(ptr %ld51)
  %cv52 = inttoptr i64 0 to ptr
  store ptr %cv52, ptr %res_slot26
  br label %case_merge12
case_merge12:
  %case_r53 = load ptr, ptr %res_slot26
  store ptr %case_r53, ptr %res_slot16
  br label %case_merge9
case_default10:
  call void @print_help()
  %cv54 = inttoptr i64 0 to ptr
  store ptr %cv54, ptr %res_slot16
  br label %case_merge9
case_merge9:
  %case_r55 = load ptr, ptr %res_slot16
  store ptr %case_r55, ptr %res_slot6
  br label %case_merge3
case_default4:
  %ld56 = load ptr, ptr %args.addr
  call void @march_decrc_local(ptr %ld56)
  call void @print_help()
  %cv57 = inttoptr i64 0 to ptr
  store ptr %cv57, ptr %res_slot6
  br label %case_merge3
case_merge3:
  %case_r58 = load ptr, ptr %res_slot6
  ret void
}

define void @print_help() {
entry:
  %sl59 = call ptr @march_string_lit(ptr @.str4, i64 29)
  call void @march_println(ptr %sl59)
  %sl60 = call ptr @march_string_lit(ptr @.str5, i64 0)
  call void @march_println(ptr %sl60)
  %sl61 = call ptr @march_string_lit(ptr @.str6, i64 9)
  call void @march_println(ptr %sl61)
  %sl62 = call ptr @march_string_lit(ptr @.str7, i64 59)
  call void @march_println(ptr %sl62)
  ret void
}

define void @cmd_new(ptr nonnull dereferenceable(16) %name.arg) {
entry:
  %name.addr = alloca ptr
  store ptr %name.arg, ptr %name.addr
  %red63 = load i64, ptr @march_tls_reductions
  %red_dec64 = sub i64 %red63, 1
  store i64 %red_dec64, ptr @march_tls_reductions
  %need_yield65 = icmp sle i64 %red_dec64, 0
  br i1 %need_yield65, label %sched_yield23, label %sched_cont24
sched_yield23:
  call void @march_yield_from_compiled()
  br label %sched_cont24
sched_cont24:
  %ld66 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld66)
  %ld67 = load ptr, ptr %name.addr
  %path_i947.addr = alloca ptr
  store ptr %ld67, ptr %path_i947.addr
  %ld68 = load ptr, ptr %path_i947.addr
  %cr69 = call i64 @march_dir_exists(ptr %ld68)
  %$t7997.addr = alloca i64
  store i64 %cr69, ptr %$t7997.addr
  %ld70 = load i64, ptr %$t7997.addr
  %res_slot71 = alloca ptr
  %bi72 = trunc i64 %ld70 to i1
  br i1 %bi72, label %case_br27, label %case_br28
case_br27:
  %sl73 = call ptr @march_string_lit(ptr @.str8, i64 18)
  %ld74 = load ptr, ptr %name.addr
  %cr75 = call ptr @march_string_concat(ptr %sl73, ptr %ld74)
  %$t7998.addr = alloca ptr
  store ptr %cr75, ptr %$t7998.addr
  %ld76 = load ptr, ptr %$t7998.addr
  %sl77 = call ptr @march_string_lit(ptr @.str9, i64 16)
  %cr78 = call ptr @march_string_concat(ptr %ld76, ptr %sl77)
  %$t7999.addr = alloca ptr
  store ptr %cr78, ptr %$t7999.addr
  %ld79 = load ptr, ptr %$t7999.addr
  call void @march_panic(ptr %ld79)
  %cv80 = inttoptr i64 0 to ptr
  store ptr %cv80, ptr %res_slot71
  br label %case_merge25
case_br28:
  %ld81 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld81)
  %sl82 = call ptr @march_string_lit(ptr @.str10, i64 22)
  %ld83 = load ptr, ptr %name.addr
  %cr84 = call ptr @march_string_concat(ptr %sl82, ptr %ld83)
  %$t8000.addr = alloca ptr
  store ptr %cr84, ptr %$t8000.addr
  %ld85 = load ptr, ptr %$t8000.addr
  call void @march_println(ptr %ld85)
  %ld86 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld86)
  %ld87 = load ptr, ptr %name.addr
  call void @scaffold(ptr %ld87)
  %sl88 = call ptr @march_string_lit(ptr @.str11, i64 0)
  call void @march_println(ptr %sl88)
  %sl89 = call ptr @march_string_lit(ptr @.str12, i64 17)
  call void @march_println(ptr %sl89)
  %sl90 = call ptr @march_string_lit(ptr @.str13, i64 0)
  call void @march_println(ptr %sl90)
  %sl91 = call ptr @march_string_lit(ptr @.str14, i64 5)
  %ld92 = load ptr, ptr %name.addr
  %cr93 = call ptr @march_string_concat(ptr %sl91, ptr %ld92)
  %$t8001.addr = alloca ptr
  store ptr %cr93, ptr %$t8001.addr
  %ld94 = load ptr, ptr %$t8001.addr
  call void @march_println(ptr %ld94)
  %sl95 = call ptr @march_string_lit(ptr @.str15, i64 12)
  call void @march_println(ptr %sl95)
  %sl96 = call ptr @march_string_lit(ptr @.str16, i64 11)
  call void @march_println(ptr %sl96)
  %sl97 = call ptr @march_string_lit(ptr @.str17, i64 0)
  call void @march_println(ptr %sl97)
  %sl98 = call ptr @march_string_lit(ptr @.str18, i64 41)
  call void @march_println(ptr %sl98)
  %cv99 = inttoptr i64 0 to ptr
  store ptr %cv99, ptr %res_slot71
  br label %case_merge25
case_default26:
  unreachable
case_merge25:
  %case_r100 = load ptr, ptr %res_slot71
  ret void
}

define void @scaffold(ptr nonnull dereferenceable(16) %name.arg) {
entry:
  %name.addr = alloca ptr
  store ptr %name.arg, ptr %name.addr
  %red101 = load i64, ptr @march_tls_reductions
  %red_dec102 = sub i64 %red101, 1
  store i64 %red_dec102, ptr @march_tls_reductions
  %need_yield103 = icmp sle i64 %red_dec102, 0
  br i1 %need_yield103, label %sched_yield29, label %sched_cont30
sched_yield29:
  call void @march_yield_from_compiled()
  br label %sched_cont30
sched_cont30:
  %ld104 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld104)
  %ld105 = load ptr, ptr %name.addr
  %cr106 = call ptr @to_pascal(ptr %ld105)
  %pascal.addr = alloca ptr
  store ptr %cr106, ptr %pascal.addr
  %ld107 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld107)
  %ld108 = load ptr, ptr %name.addr
  %path_i954.addr = alloca ptr
  store ptr %ld108, ptr %path_i954.addr
  %ld109 = load ptr, ptr %path_i954.addr
  %cr110 = call ptr @march_dir_mkdir_p(ptr %ld109)
  %ld111 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld111)
  %ld112 = load ptr, ptr %name.addr
  %sl113 = call ptr @march_string_lit(ptr @.str19, i64 4)
  %cr114 = call ptr @march_string_concat(ptr %ld112, ptr %sl113)
  %$t8002.addr = alloca ptr
  store ptr %cr114, ptr %$t8002.addr
  %ld115 = load ptr, ptr %$t8002.addr
  %path_i953.addr = alloca ptr
  store ptr %ld115, ptr %path_i953.addr
  %ld116 = load ptr, ptr %path_i953.addr
  %cr117 = call ptr @march_dir_mkdir_p(ptr %ld116)
  %ld118 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld118)
  %ld119 = load ptr, ptr %name.addr
  %sl120 = call ptr @march_string_lit(ptr @.str20, i64 7)
  %cr121 = call ptr @march_string_concat(ptr %ld119, ptr %sl120)
  %$t8003.addr = alloca ptr
  store ptr %cr121, ptr %$t8003.addr
  %ld122 = load ptr, ptr %$t8003.addr
  %path_i952.addr = alloca ptr
  store ptr %ld122, ptr %path_i952.addr
  %ld123 = load ptr, ptr %path_i952.addr
  %cr124 = call ptr @march_dir_mkdir_p(ptr %ld123)
  %ld125 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld125)
  %ld126 = load ptr, ptr %name.addr
  %sl127 = call ptr @march_string_lit(ptr @.str21, i64 11)
  %cr128 = call ptr @march_string_concat(ptr %ld126, ptr %sl127)
  %$t8004.addr = alloca ptr
  store ptr %cr128, ptr %$t8004.addr
  %ld129 = load ptr, ptr %$t8004.addr
  %path_i951.addr = alloca ptr
  store ptr %ld129, ptr %path_i951.addr
  %ld130 = load ptr, ptr %path_i951.addr
  %cr131 = call ptr @march_dir_mkdir_p(ptr %ld130)
  %ld132 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld132)
  %ld133 = load ptr, ptr %name.addr
  %sl134 = call ptr @march_string_lit(ptr @.str22, i64 10)
  %cr135 = call ptr @march_string_concat(ptr %ld133, ptr %sl134)
  %$t8005.addr = alloca ptr
  store ptr %cr135, ptr %$t8005.addr
  %ld136 = load ptr, ptr %$t8005.addr
  %path_i950.addr = alloca ptr
  store ptr %ld136, ptr %path_i950.addr
  %ld137 = load ptr, ptr %path_i950.addr
  %cr138 = call ptr @march_dir_mkdir_p(ptr %ld137)
  %ld139 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld139)
  %ld140 = load ptr, ptr %name.addr
  %sl141 = call ptr @march_string_lit(ptr @.str23, i64 8)
  %cr142 = call ptr @march_string_concat(ptr %ld140, ptr %sl141)
  %$t8006.addr = alloca ptr
  store ptr %cr142, ptr %$t8006.addr
  %ld143 = load ptr, ptr %$t8006.addr
  %path_i949.addr = alloca ptr
  store ptr %ld143, ptr %path_i949.addr
  %ld144 = load ptr, ptr %path_i949.addr
  %cr145 = call ptr @march_dir_mkdir_p(ptr %ld144)
  %ld146 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld146)
  %ld147 = load ptr, ptr %name.addr
  %sl148 = call ptr @march_string_lit(ptr @.str24, i64 5)
  %cr149 = call ptr @march_string_concat(ptr %ld147, ptr %sl148)
  %$t8007.addr = alloca ptr
  store ptr %cr149, ptr %$t8007.addr
  %ld150 = load ptr, ptr %$t8007.addr
  %path_i948.addr = alloca ptr
  store ptr %ld150, ptr %path_i948.addr
  %ld151 = load ptr, ptr %path_i948.addr
  %cr152 = call ptr @march_dir_mkdir_p(ptr %ld151)
  %ld153 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld153)
  %ld154 = load ptr, ptr %name.addr
  %sl155 = call ptr @march_string_lit(ptr @.str25, i64 11)
  %cr156 = call ptr @march_string_concat(ptr %ld154, ptr %sl155)
  %$t8008.addr = alloca ptr
  store ptr %cr156, ptr %$t8008.addr
  %ld157 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld157)
  %ld158 = load ptr, ptr %name.addr
  %cr159 = call ptr @forge_toml(ptr %ld158)
  %$t8009.addr = alloca ptr
  store ptr %cr159, ptr %$t8009.addr
  %ld160 = load ptr, ptr %$t8008.addr
  %ld161 = load ptr, ptr %$t8009.addr
  call void @write(ptr %ld160, ptr %ld161)
  %ld162 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld162)
  %ld163 = load ptr, ptr %name.addr
  %sl164 = call ptr @march_string_lit(ptr @.str26, i64 14)
  %cr165 = call ptr @march_string_concat(ptr %ld163, ptr %sl164)
  %$t8010.addr = alloca ptr
  store ptr %cr165, ptr %$t8010.addr
  %cr166 = call ptr @editorconfig()
  %$t8011.addr = alloca ptr
  store ptr %cr166, ptr %$t8011.addr
  %ld167 = load ptr, ptr %$t8010.addr
  %ld168 = load ptr, ptr %$t8011.addr
  call void @write(ptr %ld167, ptr %ld168)
  %ld169 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld169)
  %ld170 = load ptr, ptr %name.addr
  %sl171 = call ptr @march_string_lit(ptr @.str27, i64 11)
  %cr172 = call ptr @march_string_concat(ptr %ld170, ptr %sl171)
  %$t8012.addr = alloca ptr
  store ptr %cr172, ptr %$t8012.addr
  %cr173 = call ptr @gitignore()
  %$t8013.addr = alloca ptr
  store ptr %cr173, ptr %$t8013.addr
  %ld174 = load ptr, ptr %$t8012.addr
  %ld175 = load ptr, ptr %$t8013.addr
  call void @write(ptr %ld174, ptr %ld175)
  %ld176 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld176)
  %ld177 = load ptr, ptr %name.addr
  %sl178 = call ptr @march_string_lit(ptr @.str28, i64 10)
  %cr179 = call ptr @march_string_concat(ptr %ld177, ptr %sl178)
  %$t8014.addr = alloca ptr
  store ptr %cr179, ptr %$t8014.addr
  %ld180 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld180)
  %ld181 = load ptr, ptr %name.addr
  %cr182 = call ptr @readme(ptr %ld181)
  %$t8015.addr = alloca ptr
  store ptr %cr182, ptr %$t8015.addr
  %ld183 = load ptr, ptr %$t8014.addr
  %ld184 = load ptr, ptr %$t8015.addr
  call void @write(ptr %ld183, ptr %ld184)
  %ld185 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld185)
  %ld186 = load ptr, ptr %name.addr
  %sl187 = call ptr @march_string_lit(ptr @.str29, i64 5)
  %cr188 = call ptr @march_string_concat(ptr %ld186, ptr %sl187)
  %$t8016.addr = alloca ptr
  store ptr %cr188, ptr %$t8016.addr
  %ld189 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld189)
  %ld190 = load ptr, ptr %$t8016.addr
  %ld191 = load ptr, ptr %name.addr
  %cr192 = call ptr @march_string_concat(ptr %ld190, ptr %ld191)
  %$t8017.addr = alloca ptr
  store ptr %cr192, ptr %$t8017.addr
  %ld193 = load ptr, ptr %$t8017.addr
  %sl194 = call ptr @march_string_lit(ptr @.str30, i64 6)
  %cr195 = call ptr @march_string_concat(ptr %ld193, ptr %sl194)
  %$t8018.addr = alloca ptr
  store ptr %cr195, ptr %$t8018.addr
  %ld196 = load ptr, ptr %name.addr
  %ld197 = load ptr, ptr %pascal.addr
  %cr198 = call ptr @main_module(ptr %ld196, ptr %ld197)
  %$t8019.addr = alloca ptr
  store ptr %cr198, ptr %$t8019.addr
  %ld199 = load ptr, ptr %$t8018.addr
  %ld200 = load ptr, ptr %$t8019.addr
  call void @write(ptr %ld199, ptr %ld200)
  %ld201 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld201)
  %ld202 = load ptr, ptr %name.addr
  %sl203 = call ptr @march_string_lit(ptr @.str31, i64 26)
  %cr204 = call ptr @march_string_concat(ptr %ld202, ptr %sl203)
  %$t8020.addr = alloca ptr
  store ptr %cr204, ptr %$t8020.addr
  %ld205 = load ptr, ptr %pascal.addr
  %cr206 = call ptr @page_controller(ptr %ld205)
  %$t8021.addr = alloca ptr
  store ptr %cr206, ptr %$t8021.addr
  %ld207 = load ptr, ptr %$t8020.addr
  %ld208 = load ptr, ptr %$t8021.addr
  call void @write(ptr %ld207, ptr %ld208)
  %ld209 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld209)
  %ld210 = load ptr, ptr %name.addr
  %sl211 = call ptr @march_string_lit(ptr @.str32, i64 18)
  %cr212 = call ptr @march_string_concat(ptr %ld210, ptr %sl211)
  %$t8022.addr = alloca ptr
  store ptr %cr212, ptr %$t8022.addr
  %ld213 = load ptr, ptr %pascal.addr
  %cr214 = call ptr @counter_island(ptr %ld213)
  %$t8023.addr = alloca ptr
  store ptr %cr214, ptr %$t8023.addr
  %ld215 = load ptr, ptr %$t8022.addr
  %ld216 = load ptr, ptr %$t8023.addr
  call void @write(ptr %ld215, ptr %ld216)
  %ld217 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld217)
  %ld218 = load ptr, ptr %name.addr
  %sl219 = call ptr @march_string_lit(ptr @.str33, i64 19)
  %cr220 = call ptr @march_string_concat(ptr %ld218, ptr %sl219)
  %$t8024.addr = alloca ptr
  store ptr %cr220, ptr %$t8024.addr
  %cr221 = call ptr @app_css()
  %$t8025.addr = alloca ptr
  store ptr %cr221, ptr %$t8025.addr
  %ld222 = load ptr, ptr %$t8024.addr
  %ld223 = load ptr, ptr %$t8025.addr
  call void @write(ptr %ld222, ptr %ld223)
  %ld224 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld224)
  %ld225 = load ptr, ptr %name.addr
  %sl226 = call ptr @march_string_lit(ptr @.str34, i64 19)
  %cr227 = call ptr @march_string_concat(ptr %ld225, ptr %sl226)
  %$t8026.addr = alloca ptr
  store ptr %cr227, ptr %$t8026.addr
  %ld228 = load ptr, ptr %$t8026.addr
  %sl229 = call ptr @march_string_lit(ptr @.str35, i64 0)
  call void @write(ptr %ld228, ptr %sl229)
  %ld230 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld230)
  %ld231 = load ptr, ptr %name.addr
  %sl232 = call ptr @march_string_lit(ptr @.str36, i64 17)
  %cr233 = call ptr @march_string_concat(ptr %ld231, ptr %sl232)
  %$t8027.addr = alloca ptr
  store ptr %cr233, ptr %$t8027.addr
  %ld234 = load ptr, ptr %$t8027.addr
  %sl235 = call ptr @march_string_lit(ptr @.str37, i64 0)
  call void @write(ptr %ld234, ptr %sl235)
  %ld236 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld236)
  %ld237 = load ptr, ptr %name.addr
  %sl238 = call ptr @march_string_lit(ptr @.str38, i64 6)
  %cr239 = call ptr @march_string_concat(ptr %ld237, ptr %sl238)
  %$t8028.addr = alloca ptr
  store ptr %cr239, ptr %$t8028.addr
  %ld240 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld240)
  %ld241 = load ptr, ptr %$t8028.addr
  %ld242 = load ptr, ptr %name.addr
  %cr243 = call ptr @march_string_concat(ptr %ld241, ptr %ld242)
  %$t8029.addr = alloca ptr
  store ptr %cr243, ptr %$t8029.addr
  %ld244 = load ptr, ptr %$t8029.addr
  %sl245 = call ptr @march_string_lit(ptr @.str39, i64 11)
  %cr246 = call ptr @march_string_concat(ptr %ld244, ptr %sl245)
  %$t8030.addr = alloca ptr
  store ptr %cr246, ptr %$t8030.addr
  %ld247 = load ptr, ptr %name.addr
  %ld248 = load ptr, ptr %pascal.addr
  %cr249 = call ptr @test_module(ptr %ld247, ptr %ld248)
  %$t8031.addr = alloca ptr
  store ptr %cr249, ptr %$t8031.addr
  %ld250 = load ptr, ptr %$t8030.addr
  %ld251 = load ptr, ptr %$t8031.addr
  call void @write(ptr %ld250, ptr %ld251)
  %sl252 = call ptr @march_string_lit(ptr @.str40, i64 10)
  %ld253 = load ptr, ptr %name.addr
  %cr254 = call ptr @march_string_concat(ptr %sl252, ptr %ld253)
  %$t8032.addr = alloca ptr
  store ptr %cr254, ptr %$t8032.addr
  %ld255 = load ptr, ptr %$t8032.addr
  %sl256 = call ptr @march_string_lit(ptr @.str41, i64 1)
  %cr257 = call ptr @march_string_concat(ptr %ld255, ptr %sl256)
  %$t8033.addr = alloca ptr
  store ptr %cr257, ptr %$t8033.addr
  %ld258 = load ptr, ptr %$t8033.addr
  call void @march_println(ptr %ld258)
  ret void
}

define void @write(ptr nonnull dereferenceable(16) %path.arg, ptr nonnull dereferenceable(16) %content.arg) {
entry:
  %path.addr = alloca ptr
  store ptr %path.arg, ptr %path.addr
  %content.addr = alloca ptr
  store ptr %content.arg, ptr %content.addr
  %ld259 = load ptr, ptr %path.addr
  call void @march_incrc_local(ptr %ld259)
  %ld260 = load ptr, ptr %path.addr
  %path_i955.addr = alloca ptr
  store ptr %ld260, ptr %path_i955.addr
  %ld261 = load ptr, ptr %content.addr
  %data_i956.addr = alloca ptr
  store ptr %ld261, ptr %data_i956.addr
  %ld262 = load ptr, ptr %path_i955.addr
  %ld263 = load ptr, ptr %data_i956.addr
  %cr264 = call ptr @march_file_write(ptr %ld262, ptr %ld263)
  %sl265 = call ptr @march_string_lit(ptr @.str42, i64 10)
  %ld266 = load ptr, ptr %path.addr
  %cr267 = call ptr @march_string_concat(ptr %sl265, ptr %ld266)
  %$t8034.addr = alloca ptr
  store ptr %cr267, ptr %$t8034.addr
  %ld268 = load ptr, ptr %$t8034.addr
  call void @march_println(ptr %ld268)
  ret void
}

define ptr @to_pascal(ptr nonnull dereferenceable(16) %s.arg) {
entry:
  %s.addr = alloca ptr
  store ptr %s.arg, ptr %s.addr
  %red269 = load i64, ptr @march_tls_reductions
  %red_dec270 = sub i64 %red269, 1
  store i64 %red_dec270, ptr @march_tls_reductions
  %need_yield271 = icmp sle i64 %red_dec270, 0
  br i1 %need_yield271, label %sched_yield31, label %sched_cont32
sched_yield31:
  call void @march_yield_from_compiled()
  br label %sched_cont32
sched_cont32:
  %ld272 = load ptr, ptr %s.addr
  %s_i957.addr = alloca ptr
  store ptr %ld272, ptr %s_i957.addr
  %ld273 = load ptr, ptr %s_i957.addr
  %sl274 = call ptr @march_string_lit(ptr @.str43, i64 1)
  %cr275 = call ptr @march_string_split(ptr %ld273, ptr %sl274)
  %$t8035.addr = alloca ptr
  store ptr %cr275, ptr %$t8035.addr
  %ld276 = load ptr, ptr %$t8035.addr
  %sl277 = call ptr @march_string_lit(ptr @.str44, i64 0)
  %cr278 = call ptr @join_parts(ptr %ld276, ptr %sl277)
  %$rc_192.addr = alloca ptr
  store ptr %cr278, ptr %$rc_192.addr
  %ld279 = load ptr, ptr %$t8035.addr
  call void @march_decrc_local(ptr %ld279)
  %ld280 = load ptr, ptr %$rc_192.addr
  ret ptr %ld280
}

define ptr @join_parts(ptr nonnull dereferenceable(16) %parts.arg, ptr nonnull dereferenceable(16) %acc.arg) {
entry:
  %parts.addr = alloca ptr
  store ptr %parts.arg, ptr %parts.addr
  %acc.addr = alloca ptr
  store ptr %acc.arg, ptr %acc.addr
  br label %tco_loop33
tco_loop33:
  %red281 = load i64, ptr @march_tls_reductions
  %red_dec282 = sub i64 %red281, 1
  store i64 %red_dec282, ptr @march_tls_reductions
  %need_yield283 = icmp sle i64 %red_dec282, 0
  br i1 %need_yield283, label %sched_yield34, label %sched_cont35
sched_yield34:
  call void @march_yield_from_compiled()
  br label %sched_cont35
sched_cont35:
  %ld284 = load ptr, ptr %parts.addr
  %res_slot285 = alloca ptr
  %tgp286 = getelementptr i8, ptr %ld284, i64 8
  %tag287 = load i32, ptr %tgp286, align 4
  switch i32 %tag287, label %case_default37 [
      i32 0, label %case_br38
      i32 1, label %case_br39
  ]
case_br38:
  %ld288 = load ptr, ptr %acc.addr
  store ptr %ld288, ptr %res_slot285
  br label %case_merge36
case_br39:
  %fp289 = getelementptr i8, ptr %ld284, i64 16
  %fv290 = load ptr, ptr %fp289, align 8
  %$f8038.addr = alloca ptr
  store ptr %fv290, ptr %$f8038.addr
  %fp291 = getelementptr i8, ptr %ld284, i64 24
  %fv292 = load ptr, ptr %fp291, align 8
  %$f8039.addr = alloca ptr
  store ptr %fv292, ptr %$f8039.addr
  %ld293 = load ptr, ptr %$f8039.addr
  %rest.addr = alloca ptr
  store ptr %ld293, ptr %rest.addr
  %ld294 = load ptr, ptr %$f8038.addr
  %part.addr = alloca ptr
  store ptr %ld294, ptr %part.addr
  %ld295 = load ptr, ptr %part.addr
  %cr296 = call ptr @capitalise(ptr %ld295)
  %$t8036.addr = alloca ptr
  store ptr %cr296, ptr %$t8036.addr
  %ld297 = load ptr, ptr %acc.addr
  %ld298 = load ptr, ptr %$t8036.addr
  %cr299 = call ptr @march_string_concat(ptr %ld297, ptr %ld298)
  %$t8037.addr = alloca ptr
  store ptr %cr299, ptr %$t8037.addr
  %ld300 = load ptr, ptr %rest.addr
  %ld301 = load ptr, ptr %$t8037.addr
  store ptr %ld300, ptr %parts.addr
  store ptr %ld301, ptr %acc.addr
  br label %tco_loop33
tco_cont40:
  %ld302 = load ptr, ptr %rest.addr
  call void @march_decrc_local(ptr %ld302)
  %cv303 = inttoptr i64 0 to ptr
  store ptr %cv303, ptr %res_slot285
  br label %case_merge36
case_default37:
  unreachable
case_merge36:
  %case_r304 = load ptr, ptr %res_slot285
  ret ptr %case_r304
}

define ptr @capitalise(ptr nonnull dereferenceable(16) %s.arg) {
entry:
  %s.addr = alloca ptr
  store ptr %s.arg, ptr %s.addr
  %ld305 = load ptr, ptr %s.addr
  call void @march_incrc_local(ptr %ld305)
  %ld306 = load ptr, ptr %s.addr
  %s_i967.addr = alloca ptr
  store ptr %ld306, ptr %s_i967.addr
  %ld307 = load ptr, ptr %s_i967.addr
  %cr308 = call i64 @march_string_is_empty(ptr %ld307)
  %$t8040.addr = alloca i64
  store i64 %cr308, ptr %$t8040.addr
  %ld309 = load i64, ptr %$t8040.addr
  %res_slot310 = alloca ptr
  %bi311 = trunc i64 %ld309 to i1
  br i1 %bi311, label %case_br43, label %case_br44
case_br43:
  %ld312 = load ptr, ptr %s.addr
  store ptr %ld312, ptr %res_slot310
  br label %case_merge41
case_br44:
  %ld313 = load ptr, ptr %s.addr
  call void @march_incrc_local(ptr %ld313)
  %ld314 = load ptr, ptr %s.addr
  %s_i964.addr = alloca ptr
  store ptr %ld314, ptr %s_i964.addr
  %ld315 = load ptr, ptr %s_i964.addr
  %cr316 = call ptr @march_string_slice(ptr %ld315, i64 0, i64 1)
  %head.addr = alloca ptr
  store ptr %cr316, ptr %head.addr
  %ld317 = load ptr, ptr %s.addr
  call void @march_incrc_local(ptr %ld317)
  %ld318 = load ptr, ptr %s.addr
  %s_i963.addr = alloca ptr
  store ptr %ld318, ptr %s_i963.addr
  %ld319 = load ptr, ptr %s_i963.addr
  %cr320 = call i64 @march_string_byte_length(ptr %ld319)
  %$t8041.addr = alloca i64
  store i64 %cr320, ptr %$t8041.addr
  %ld321 = load i64, ptr %$t8041.addr
  %ar322 = sub i64 %ld321, 1
  %$t8042.addr = alloca i64
  store i64 %ar322, ptr %$t8042.addr
  %ld323 = load ptr, ptr %s.addr
  %s_i960.addr = alloca ptr
  store ptr %ld323, ptr %s_i960.addr
  %ld324 = load i64, ptr %$t8042.addr
  %len_i962.addr = alloca i64
  store i64 %ld324, ptr %len_i962.addr
  %ld325 = load ptr, ptr %s_i960.addr
  %ld326 = load i64, ptr %len_i962.addr
  %cr327 = call ptr @march_string_slice(ptr %ld325, i64 1, i64 %ld326)
  %tail.addr = alloca ptr
  store ptr %cr327, ptr %tail.addr
  %ld328 = load ptr, ptr %head.addr
  %s_i959.addr = alloca ptr
  store ptr %ld328, ptr %s_i959.addr
  %ld329 = load ptr, ptr %s_i959.addr
  %cr330 = call ptr @march_string_to_uppercase(ptr %ld329)
  %$t8043.addr = alloca ptr
  store ptr %cr330, ptr %$t8043.addr
  %ld331 = load ptr, ptr %$t8043.addr
  %ld332 = load ptr, ptr %tail.addr
  %cr333 = call ptr @march_string_concat(ptr %ld331, ptr %ld332)
  store ptr %cr333, ptr %res_slot310
  br label %case_merge41
case_default42:
  unreachable
case_merge41:
  %case_r334 = load ptr, ptr %res_slot310
  ret ptr %case_r334
}

define ptr @forge_toml(ptr nonnull dereferenceable(16) %name.arg) {
entry:
  %name.addr = alloca ptr
  store ptr %name.arg, ptr %name.addr
  %sl335 = call ptr @march_string_lit(ptr @.str45, i64 10)
  %sl336 = call ptr @march_string_lit(ptr @.str46, i64 8)
  %cr337 = call ptr @march_string_concat(ptr %sl335, ptr %sl336)
  %$t8044.addr = alloca ptr
  store ptr %cr337, ptr %$t8044.addr
  %ld338 = load ptr, ptr %$t8044.addr
  %ld339 = load ptr, ptr %name.addr
  %cr340 = call ptr @march_string_concat(ptr %ld338, ptr %ld339)
  %$t8045.addr = alloca ptr
  store ptr %cr340, ptr %$t8045.addr
  %ld341 = load ptr, ptr %$t8045.addr
  %sl342 = call ptr @march_string_lit(ptr @.str47, i64 2)
  %cr343 = call ptr @march_string_concat(ptr %ld341, ptr %sl342)
  %$t8046.addr = alloca ptr
  store ptr %cr343, ptr %$t8046.addr
  %ld344 = load ptr, ptr %$t8046.addr
  %sl345 = call ptr @march_string_lit(ptr @.str48, i64 18)
  %cr346 = call ptr @march_string_concat(ptr %ld344, ptr %sl345)
  %$t8047.addr = alloca ptr
  store ptr %cr346, ptr %$t8047.addr
  %ld347 = load ptr, ptr %$t8047.addr
  %sl348 = call ptr @march_string_lit(ptr @.str49, i64 13)
  %cr349 = call ptr @march_string_concat(ptr %ld347, ptr %sl348)
  %$t8048.addr = alloca ptr
  store ptr %cr349, ptr %$t8048.addr
  %ld350 = load ptr, ptr %$t8048.addr
  %sl351 = call ptr @march_string_lit(ptr @.str50, i64 17)
  %cr352 = call ptr @march_string_concat(ptr %ld350, ptr %sl351)
  %$t8049.addr = alloca ptr
  store ptr %cr352, ptr %$t8049.addr
  %ld353 = load ptr, ptr %$t8049.addr
  %sl354 = call ptr @march_string_lit(ptr @.str51, i64 12)
  %cr355 = call ptr @march_string_concat(ptr %ld353, ptr %sl354)
  %$t8050.addr = alloca ptr
  store ptr %cr355, ptr %$t8050.addr
  %ld356 = load ptr, ptr %$t8050.addr
  %sl357 = call ptr @march_string_lit(ptr @.str52, i64 1)
  %cr358 = call ptr @march_string_concat(ptr %ld356, ptr %sl357)
  %$t8051.addr = alloca ptr
  store ptr %cr358, ptr %$t8051.addr
  %ld359 = load ptr, ptr %$t8051.addr
  %sl360 = call ptr @march_string_lit(ptr @.str53, i64 7)
  %cr361 = call ptr @march_string_concat(ptr %ld359, ptr %sl360)
  %$t8052.addr = alloca ptr
  store ptr %cr361, ptr %$t8052.addr
  %ld362 = load ptr, ptr %$t8052.addr
  %sl363 = call ptr @march_string_lit(ptr @.str54, i64 34)
  %cr364 = call ptr @march_string_concat(ptr %ld362, ptr %sl363)
  %$t8053.addr = alloca ptr
  store ptr %cr364, ptr %$t8053.addr
  %ld365 = load ptr, ptr %$t8053.addr
  %sl366 = call ptr @march_string_lit(ptr @.str55, i64 34)
  %cr367 = call ptr @march_string_concat(ptr %ld365, ptr %sl366)
  ret ptr %cr367
}

define ptr @editorconfig() {
entry:
  %sl368 = call ptr @march_string_lit(ptr @.str56, i64 13)
  %sl369 = call ptr @march_string_lit(ptr @.str57, i64 4)
  %cr370 = call ptr @march_string_concat(ptr %sl368, ptr %sl369)
  %$t8054.addr = alloca ptr
  store ptr %cr370, ptr %$t8054.addr
  %ld371 = load ptr, ptr %$t8054.addr
  %sl372 = call ptr @march_string_lit(ptr @.str58, i64 21)
  %cr373 = call ptr @march_string_concat(ptr %ld371, ptr %sl372)
  %$t8055.addr = alloca ptr
  store ptr %cr373, ptr %$t8055.addr
  %ld374 = load ptr, ptr %$t8055.addr
  %sl375 = call ptr @march_string_lit(ptr @.str59, i64 16)
  %cr376 = call ptr @march_string_concat(ptr %ld374, ptr %sl375)
  %$t8056.addr = alloca ptr
  store ptr %cr376, ptr %$t8056.addr
  %ld377 = load ptr, ptr %$t8056.addr
  %sl378 = call ptr @march_string_lit(ptr @.str60, i64 16)
  %cr379 = call ptr @march_string_concat(ptr %ld377, ptr %sl378)
  %$t8057.addr = alloca ptr
  store ptr %cr379, ptr %$t8057.addr
  %ld380 = load ptr, ptr %$t8057.addr
  %sl381 = call ptr @march_string_lit(ptr @.str61, i64 17)
  %cr382 = call ptr @march_string_concat(ptr %ld380, ptr %sl381)
  %$t8058.addr = alloca ptr
  store ptr %cr382, ptr %$t8058.addr
  %ld383 = load ptr, ptr %$t8058.addr
  %sl384 = call ptr @march_string_lit(ptr @.str62, i64 32)
  %cr385 = call ptr @march_string_concat(ptr %ld383, ptr %sl384)
  %$t8059.addr = alloca ptr
  store ptr %cr385, ptr %$t8059.addr
  %ld386 = load ptr, ptr %$t8059.addr
  %sl387 = call ptr @march_string_lit(ptr @.str63, i64 29)
  %cr388 = call ptr @march_string_concat(ptr %ld386, ptr %sl387)
  %$t8060.addr = alloca ptr
  store ptr %cr388, ptr %$t8060.addr
  %ld389 = load ptr, ptr %$t8060.addr
  %sl390 = call ptr @march_string_lit(ptr @.str64, i64 10)
  %cr391 = call ptr @march_string_concat(ptr %ld389, ptr %sl390)
  %$t8061.addr = alloca ptr
  store ptr %cr391, ptr %$t8061.addr
  %ld392 = load ptr, ptr %$t8061.addr
  %sl393 = call ptr @march_string_lit(ptr @.str65, i64 21)
  %cr394 = call ptr @march_string_concat(ptr %ld392, ptr %sl393)
  %$t8062.addr = alloca ptr
  store ptr %cr394, ptr %$t8062.addr
  %ld395 = load ptr, ptr %$t8062.addr
  %sl396 = call ptr @march_string_lit(ptr @.str66, i64 16)
  %cr397 = call ptr @march_string_concat(ptr %ld395, ptr %sl396)
  ret ptr %cr397
}

define ptr @gitignore() {
entry:
  %sl398 = call ptr @march_string_lit(ptr @.str67, i64 9)
  %sl399 = call ptr @march_string_lit(ptr @.str68, i64 16)
  %cr400 = call ptr @march_string_concat(ptr %sl398, ptr %sl399)
  %$t8063.addr = alloca ptr
  store ptr %cr400, ptr %$t8063.addr
  %ld401 = load ptr, ptr %$t8063.addr
  %sl402 = call ptr @march_string_lit(ptr @.str69, i64 19)
  %cr403 = call ptr @march_string_concat(ptr %ld401, ptr %sl402)
  ret ptr %cr403
}

define ptr @readme(ptr nonnull dereferenceable(16) %name.arg) {
entry:
  %name.addr = alloca ptr
  store ptr %name.arg, ptr %name.addr
  %red404 = load i64, ptr @march_tls_reductions
  %red_dec405 = sub i64 %red404, 1
  store i64 %red_dec405, ptr @march_tls_reductions
  %need_yield406 = icmp sle i64 %red_dec405, 0
  br i1 %need_yield406, label %sched_yield45, label %sched_cont46
sched_yield45:
  call void @march_yield_from_compiled()
  br label %sched_cont46
sched_cont46:
  %ld407 = load ptr, ptr %name.addr
  call void @march_incrc_local(ptr %ld407)
  %ld408 = load ptr, ptr %name.addr
  %cr409 = call ptr @to_pascal(ptr %ld408)
  %$t8064.addr = alloca ptr
  store ptr %cr409, ptr %$t8064.addr
  %sl410 = call ptr @march_string_lit(ptr @.str70, i64 2)
  %ld411 = load ptr, ptr %$t8064.addr
  %cr412 = call ptr @march_string_concat(ptr %sl410, ptr %ld411)
  %$t8065.addr = alloca ptr
  store ptr %cr412, ptr %$t8065.addr
  %ld413 = load ptr, ptr %$t8065.addr
  %sl414 = call ptr @march_string_lit(ptr @.str71, i64 2)
  %cr415 = call ptr @march_string_concat(ptr %ld413, ptr %sl414)
  %$t8066.addr = alloca ptr
  store ptr %cr415, ptr %$t8066.addr
  %ld416 = load ptr, ptr %$t8066.addr
  %sl417 = call ptr @march_string_lit(ptr @.str72, i64 69)
  %cr418 = call ptr @march_string_concat(ptr %ld416, ptr %sl417)
  %$t8067.addr = alloca ptr
  store ptr %cr418, ptr %$t8067.addr
  %ld419 = load ptr, ptr %$t8067.addr
  %sl420 = call ptr @march_string_lit(ptr @.str73, i64 20)
  %cr421 = call ptr @march_string_concat(ptr %ld419, ptr %sl420)
  %$t8068.addr = alloca ptr
  store ptr %cr421, ptr %$t8068.addr
  %ld422 = load ptr, ptr %$t8068.addr
  %sl423 = call ptr @march_string_lit(ptr @.str74, i64 8)
  %cr424 = call ptr @march_string_concat(ptr %ld422, ptr %sl423)
  %$t8069.addr = alloca ptr
  store ptr %cr424, ptr %$t8069.addr
  %ld425 = load ptr, ptr %$t8069.addr
  %sl426 = call ptr @march_string_lit(ptr @.str75, i64 11)
  %cr427 = call ptr @march_string_concat(ptr %ld425, ptr %sl426)
  %$t8070.addr = alloca ptr
  store ptr %cr427, ptr %$t8070.addr
  %ld428 = load ptr, ptr %$t8070.addr
  %sl429 = call ptr @march_string_lit(ptr @.str76, i64 10)
  %cr430 = call ptr @march_string_concat(ptr %ld428, ptr %sl429)
  %$t8071.addr = alloca ptr
  store ptr %cr430, ptr %$t8071.addr
  %ld431 = load ptr, ptr %$t8071.addr
  %sl432 = call ptr @march_string_lit(ptr @.str77, i64 5)
  %cr433 = call ptr @march_string_concat(ptr %ld431, ptr %sl432)
  %$t8072.addr = alloca ptr
  store ptr %cr433, ptr %$t8072.addr
  %ld434 = load ptr, ptr %$t8072.addr
  %sl435 = call ptr @march_string_lit(ptr @.str78, i64 29)
  %cr436 = call ptr @march_string_concat(ptr %ld434, ptr %sl435)
  %$t8073.addr = alloca ptr
  store ptr %cr436, ptr %$t8073.addr
  %ld437 = load ptr, ptr %$t8073.addr
  %sl438 = call ptr @march_string_lit(ptr @.str79, i64 14)
  %cr439 = call ptr @march_string_concat(ptr %ld437, ptr %sl438)
  %$t8074.addr = alloca ptr
  store ptr %cr439, ptr %$t8074.addr
  %ld440 = load ptr, ptr %$t8074.addr
  %sl441 = call ptr @march_string_lit(ptr @.str80, i64 4)
  %cr442 = call ptr @march_string_concat(ptr %ld440, ptr %sl441)
  %$t8075.addr = alloca ptr
  store ptr %cr442, ptr %$t8075.addr
  %ld443 = load ptr, ptr %$t8075.addr
  %sl444 = call ptr @march_string_lit(ptr @.str81, i64 5)
  %cr445 = call ptr @march_string_concat(ptr %ld443, ptr %sl444)
  %$t8076.addr = alloca ptr
  store ptr %cr445, ptr %$t8076.addr
  %ld446 = load ptr, ptr %$t8076.addr
  %sl447 = call ptr @march_string_lit(ptr @.str82, i64 2)
  %cr448 = call ptr @march_string_concat(ptr %ld446, ptr %sl447)
  %$t8077.addr = alloca ptr
  store ptr %cr448, ptr %$t8077.addr
  %ld449 = load ptr, ptr %$t8077.addr
  %ld450 = load ptr, ptr %name.addr
  %cr451 = call ptr @march_string_concat(ptr %ld449, ptr %ld450)
  %$t8078.addr = alloca ptr
  store ptr %cr451, ptr %$t8078.addr
  %ld452 = load ptr, ptr %$t8078.addr
  %sl453 = call ptr @march_string_lit(ptr @.str83, i64 48)
  %cr454 = call ptr @march_string_concat(ptr %ld452, ptr %sl453)
  %$t8079.addr = alloca ptr
  store ptr %cr454, ptr %$t8079.addr
  %ld455 = load ptr, ptr %$t8079.addr
  %sl456 = call ptr @march_string_lit(ptr @.str84, i64 41)
  %cr457 = call ptr @march_string_concat(ptr %ld455, ptr %sl456)
  %$t8080.addr = alloca ptr
  store ptr %cr457, ptr %$t8080.addr
  %ld458 = load ptr, ptr %$t8080.addr
  %sl459 = call ptr @march_string_lit(ptr @.str85, i64 52)
  %cr460 = call ptr @march_string_concat(ptr %ld458, ptr %sl459)
  %$t8081.addr = alloca ptr
  store ptr %cr460, ptr %$t8081.addr
  %ld461 = load ptr, ptr %$t8081.addr
  %sl462 = call ptr @march_string_lit(ptr @.str86, i64 59)
  %cr463 = call ptr @march_string_concat(ptr %ld461, ptr %sl462)
  %$t8082.addr = alloca ptr
  store ptr %cr463, ptr %$t8082.addr
  %ld464 = load ptr, ptr %$t8082.addr
  %sl465 = call ptr @march_string_lit(ptr @.str87, i64 57)
  %cr466 = call ptr @march_string_concat(ptr %ld464, ptr %sl465)
  %$t8083.addr = alloca ptr
  store ptr %cr466, ptr %$t8083.addr
  %ld467 = load ptr, ptr %$t8083.addr
  %sl468 = call ptr @march_string_lit(ptr @.str88, i64 33)
  %cr469 = call ptr @march_string_concat(ptr %ld467, ptr %sl468)
  %$t8084.addr = alloca ptr
  store ptr %cr469, ptr %$t8084.addr
  %ld470 = load ptr, ptr %$t8084.addr
  %sl471 = call ptr @march_string_lit(ptr @.str89, i64 5)
  %cr472 = call ptr @march_string_concat(ptr %ld470, ptr %sl471)
  %$t8085.addr = alloca ptr
  store ptr %cr472, ptr %$t8085.addr
  %ld473 = load ptr, ptr %$t8085.addr
  %sl474 = call ptr @march_string_lit(ptr @.str90, i64 12)
  %cr475 = call ptr @march_string_concat(ptr %ld473, ptr %sl474)
  %$t8086.addr = alloca ptr
  store ptr %cr475, ptr %$t8086.addr
  %ld476 = load ptr, ptr %$t8086.addr
  %sl477 = call ptr @march_string_lit(ptr @.str91, i64 28)
  %cr478 = call ptr @march_string_concat(ptr %ld476, ptr %sl477)
  %$t8087.addr = alloca ptr
  store ptr %cr478, ptr %$t8087.addr
  %ld479 = load ptr, ptr %$t8087.addr
  %sl480 = call ptr @march_string_lit(ptr @.str92, i64 8)
  %cr481 = call ptr @march_string_concat(ptr %ld479, ptr %sl480)
  %$t8088.addr = alloca ptr
  store ptr %cr481, ptr %$t8088.addr
  %ld482 = load ptr, ptr %$t8088.addr
  %sl483 = call ptr @march_string_lit(ptr @.str93, i64 90)
  %cr484 = call ptr @march_string_concat(ptr %ld482, ptr %sl483)
  %$t8089.addr = alloca ptr
  store ptr %cr484, ptr %$t8089.addr
  %ld485 = load ptr, ptr %$t8089.addr
  %sl486 = call ptr @march_string_lit(ptr @.str94, i64 4)
  %cr487 = call ptr @march_string_concat(ptr %ld485, ptr %sl486)
  ret ptr %cr487
}

define ptr @main_module(ptr nonnull dereferenceable(16) %_name.arg, ptr nonnull dereferenceable(16) %pascal.arg) {
entry:
  %_name.addr = alloca ptr
  store ptr %_name.arg, ptr %_name.addr
  %pascal.addr = alloca ptr
  store ptr %pascal.arg, ptr %pascal.addr
  %ld488 = load ptr, ptr %pascal.addr
  call void @march_incrc_local(ptr %ld488)
  %sl489 = call ptr @march_string_lit(ptr @.str95, i64 4)
  %ld490 = load ptr, ptr %pascal.addr
  %cr491 = call ptr @march_string_concat(ptr %sl489, ptr %ld490)
  %$t8090.addr = alloca ptr
  store ptr %cr491, ptr %$t8090.addr
  %ld492 = load ptr, ptr %$t8090.addr
  %sl493 = call ptr @march_string_lit(ptr @.str96, i64 5)
  %cr494 = call ptr @march_string_concat(ptr %ld492, ptr %sl493)
  %$t8091.addr = alloca ptr
  store ptr %cr494, ptr %$t8091.addr
  %ld495 = load ptr, ptr %$t8091.addr
  %sl496 = call ptr @march_string_lit(ptr @.str97, i64 20)
  %cr497 = call ptr @march_string_concat(ptr %ld495, ptr %sl496)
  %$t8092.addr = alloca ptr
  store ptr %cr497, ptr %$t8092.addr
  %ld498 = load ptr, ptr %$t8092.addr
  %sl499 = call ptr @march_string_lit(ptr @.str98, i64 16)
  %cr500 = call ptr @march_string_concat(ptr %ld498, ptr %sl499)
  %$t8093.addr = alloca ptr
  store ptr %cr500, ptr %$t8093.addr
  %ld501 = load ptr, ptr %$t8093.addr
  %sl502 = call ptr @march_string_lit(ptr @.str99, i64 20)
  %cr503 = call ptr @march_string_concat(ptr %ld501, ptr %sl502)
  %$t8094.addr = alloca ptr
  store ptr %cr503, ptr %$t8094.addr
  %ld504 = load ptr, ptr %$t8094.addr
  %sl505 = call ptr @march_string_lit(ptr @.str100, i64 25)
  %cr506 = call ptr @march_string_concat(ptr %ld504, ptr %sl505)
  %$t8095.addr = alloca ptr
  store ptr %cr506, ptr %$t8095.addr
  %ld507 = load ptr, ptr %$t8095.addr
  %sl508 = call ptr @march_string_lit(ptr @.str101, i64 33)
  %cr509 = call ptr @march_string_concat(ptr %ld507, ptr %sl508)
  %$t8096.addr = alloca ptr
  store ptr %cr509, ptr %$t8096.addr
  %ld510 = load ptr, ptr %$t8096.addr
  %sl511 = call ptr @march_string_lit(ptr @.str102, i64 17)
  %cr512 = call ptr @march_string_concat(ptr %ld510, ptr %sl511)
  %$t8097.addr = alloca ptr
  store ptr %cr512, ptr %$t8097.addr
  %ld513 = load ptr, ptr %$t8097.addr
  %sl514 = call ptr @march_string_lit(ptr @.str103, i64 67)
  %cr515 = call ptr @march_string_concat(ptr %ld513, ptr %sl514)
  %$t8098.addr = alloca ptr
  store ptr %cr515, ptr %$t8098.addr
  %ld516 = load ptr, ptr %$t8098.addr
  %sl517 = call ptr @march_string_lit(ptr @.str104, i64 68)
  %cr518 = call ptr @march_string_concat(ptr %ld516, ptr %sl517)
  %$t8099.addr = alloca ptr
  store ptr %cr518, ptr %$t8099.addr
  %ld519 = load ptr, ptr %$t8099.addr
  %sl520 = call ptr @march_string_lit(ptr @.str105, i64 54)
  %cr521 = call ptr @march_string_concat(ptr %ld519, ptr %sl520)
  %$t8100.addr = alloca ptr
  store ptr %cr521, ptr %$t8100.addr
  %ld522 = load ptr, ptr %$t8100.addr
  %sl523 = call ptr @march_string_lit(ptr @.str106, i64 7)
  %cr524 = call ptr @march_string_concat(ptr %ld522, ptr %sl523)
  %$t8101.addr = alloca ptr
  store ptr %cr524, ptr %$t8101.addr
  %ld525 = load ptr, ptr %$t8101.addr
  %sl526 = call ptr @march_string_lit(ptr @.str107, i64 36)
  %cr527 = call ptr @march_string_concat(ptr %ld525, ptr %sl526)
  %$t8102.addr = alloca ptr
  store ptr %cr527, ptr %$t8102.addr
  %ld528 = load ptr, ptr %$t8102.addr
  %sl529 = call ptr @march_string_lit(ptr @.str108, i64 54)
  %cr530 = call ptr @march_string_concat(ptr %ld528, ptr %sl529)
  %$t8103.addr = alloca ptr
  store ptr %cr530, ptr %$t8103.addr
  %ld531 = load ptr, ptr %$t8103.addr
  %sl532 = call ptr @march_string_lit(ptr @.str109, i64 7)
  %cr533 = call ptr @march_string_concat(ptr %ld531, ptr %sl532)
  %$t8104.addr = alloca ptr
  store ptr %cr533, ptr %$t8104.addr
  %ld534 = load ptr, ptr %$t8104.addr
  %sl535 = call ptr @march_string_lit(ptr @.str110, i64 22)
  %cr536 = call ptr @march_string_concat(ptr %ld534, ptr %sl535)
  %$t8105.addr = alloca ptr
  store ptr %cr536, ptr %$t8105.addr
  %ld537 = load ptr, ptr %$t8105.addr
  %sl538 = call ptr @march_string_lit(ptr @.str111, i64 33)
  %cr539 = call ptr @march_string_concat(ptr %ld537, ptr %sl538)
  %$t8106.addr = alloca ptr
  store ptr %cr539, ptr %$t8106.addr
  %ld540 = load ptr, ptr %$t8106.addr
  %sl541 = call ptr @march_string_lit(ptr @.str112, i64 41)
  %cr542 = call ptr @march_string_concat(ptr %ld540, ptr %sl541)
  %$t8107.addr = alloca ptr
  store ptr %cr542, ptr %$t8107.addr
  %ld543 = load ptr, ptr %$t8107.addr
  %sl544 = call ptr @march_string_lit(ptr @.str113, i64 32)
  %cr545 = call ptr @march_string_concat(ptr %ld543, ptr %sl544)
  %$t8108.addr = alloca ptr
  store ptr %cr545, ptr %$t8108.addr
  %ld546 = load ptr, ptr %$t8108.addr
  %sl547 = call ptr @march_string_lit(ptr @.str114, i64 28)
  %cr548 = call ptr @march_string_concat(ptr %ld546, ptr %sl547)
  %$t8109.addr = alloca ptr
  store ptr %cr548, ptr %$t8109.addr
  %ld549 = load ptr, ptr %$t8109.addr
  %sl550 = call ptr @march_string_lit(ptr @.str115, i64 30)
  %cr551 = call ptr @march_string_concat(ptr %ld549, ptr %sl550)
  %$t8110.addr = alloca ptr
  store ptr %cr551, ptr %$t8110.addr
  %ld552 = load ptr, ptr %$t8110.addr
  %sl553 = call ptr @march_string_lit(ptr @.str116, i64 24)
  %cr554 = call ptr @march_string_concat(ptr %ld552, ptr %sl553)
  %$t8111.addr = alloca ptr
  store ptr %cr554, ptr %$t8111.addr
  %ld555 = load ptr, ptr %$t8111.addr
  %sl556 = call ptr @march_string_lit(ptr @.str117, i64 37)
  %cr557 = call ptr @march_string_concat(ptr %ld555, ptr %sl556)
  %$t8112.addr = alloca ptr
  store ptr %cr557, ptr %$t8112.addr
  %ld558 = load ptr, ptr %$t8112.addr
  %sl559 = call ptr @march_string_lit(ptr @.str118, i64 18)
  %cr560 = call ptr @march_string_concat(ptr %ld558, ptr %sl559)
  %$t8113.addr = alloca ptr
  store ptr %cr560, ptr %$t8113.addr
  %ld561 = load ptr, ptr %$t8113.addr
  %sl562 = call ptr @march_string_lit(ptr @.str119, i64 24)
  %cr563 = call ptr @march_string_concat(ptr %ld561, ptr %sl562)
  %$t8114.addr = alloca ptr
  store ptr %cr563, ptr %$t8114.addr
  %ld564 = load ptr, ptr %$t8114.addr
  %sl565 = call ptr @march_string_lit(ptr @.str120, i64 10)
  %cr566 = call ptr @march_string_concat(ptr %ld564, ptr %sl565)
  %$t8115.addr = alloca ptr
  store ptr %cr566, ptr %$t8115.addr
  %ld567 = load ptr, ptr %$t8115.addr
  %sl568 = call ptr @march_string_lit(ptr @.str121, i64 8)
  %cr569 = call ptr @march_string_concat(ptr %ld567, ptr %sl568)
  %$t8116.addr = alloca ptr
  store ptr %cr569, ptr %$t8116.addr
  %ld570 = load ptr, ptr %$t8116.addr
  %sl571 = call ptr @march_string_lit(ptr @.str122, i64 13)
  %cr572 = call ptr @march_string_concat(ptr %ld570, ptr %sl571)
  %$t8117.addr = alloca ptr
  store ptr %cr572, ptr %$t8117.addr
  %ld573 = load ptr, ptr %$t8117.addr
  %ld574 = load ptr, ptr %pascal.addr
  %cr575 = call ptr @march_string_concat(ptr %ld573, ptr %ld574)
  %$t8118.addr = alloca ptr
  store ptr %cr575, ptr %$t8118.addr
  %ld576 = load ptr, ptr %$t8118.addr
  %sl577 = call ptr @march_string_lit(ptr @.str123, i64 38)
  %cr578 = call ptr @march_string_concat(ptr %ld576, ptr %sl577)
  %$t8119.addr = alloca ptr
  store ptr %cr578, ptr %$t8119.addr
  %ld579 = load ptr, ptr %$t8119.addr
  %sl580 = call ptr @march_string_lit(ptr @.str124, i64 25)
  %cr581 = call ptr @march_string_concat(ptr %ld579, ptr %sl580)
  %$t8120.addr = alloca ptr
  store ptr %cr581, ptr %$t8120.addr
  %ld582 = load ptr, ptr %$t8120.addr
  %sl583 = call ptr @march_string_lit(ptr @.str125, i64 32)
  %cr584 = call ptr @march_string_concat(ptr %ld582, ptr %sl583)
  %$t8121.addr = alloca ptr
  store ptr %cr584, ptr %$t8121.addr
  %ld585 = load ptr, ptr %$t8121.addr
  %sl586 = call ptr @march_string_lit(ptr @.str126, i64 27)
  %cr587 = call ptr @march_string_concat(ptr %ld585, ptr %sl586)
  %$t8122.addr = alloca ptr
  store ptr %cr587, ptr %$t8122.addr
  %ld588 = load ptr, ptr %$t8122.addr
  %sl589 = call ptr @march_string_lit(ptr @.str127, i64 7)
  %cr590 = call ptr @march_string_concat(ptr %ld588, ptr %sl589)
  %$t8123.addr = alloca ptr
  store ptr %cr590, ptr %$t8123.addr
  %ld591 = load ptr, ptr %$t8123.addr
  %sl592 = call ptr @march_string_lit(ptr @.str128, i64 4)
  %cr593 = call ptr @march_string_concat(ptr %ld591, ptr %sl592)
  ret ptr %cr593
}

define ptr @page_controller(ptr nonnull dereferenceable(16) %pascal.arg) {
entry:
  %pascal.addr = alloca ptr
  store ptr %pascal.arg, ptr %pascal.addr
  %sl594 = call ptr @march_string_lit(ptr @.str129, i64 23)
  %sl595 = call ptr @march_string_lit(ptr @.str130, i64 21)
  %cr596 = call ptr @march_string_concat(ptr %sl594, ptr %sl595)
  %$t8124.addr = alloca ptr
  store ptr %cr596, ptr %$t8124.addr
  %ld597 = load ptr, ptr %$t8124.addr
  %sl598 = call ptr @march_string_lit(ptr @.str131, i64 33)
  %cr599 = call ptr @march_string_concat(ptr %ld597, ptr %sl598)
  %$t8125.addr = alloca ptr
  store ptr %cr599, ptr %$t8125.addr
  %ld600 = load ptr, ptr %$t8125.addr
  %sl601 = call ptr @march_string_lit(ptr @.str132, i64 46)
  %cr602 = call ptr @march_string_concat(ptr %ld600, ptr %sl601)
  %$t8126.addr = alloca ptr
  store ptr %cr602, ptr %$t8126.addr
  %ld603 = load ptr, ptr %$t8126.addr
  %sl604 = call ptr @march_string_lit(ptr @.str133, i64 22)
  %cr605 = call ptr @march_string_concat(ptr %ld603, ptr %sl604)
  %$t8127.addr = alloca ptr
  store ptr %cr605, ptr %$t8127.addr
  %ld606 = load ptr, ptr %pascal.addr
  call void @march_incrc_local(ptr %ld606)
  %ld607 = load ptr, ptr %$t8127.addr
  %ld608 = load ptr, ptr %pascal.addr
  %cr609 = call ptr @march_string_concat(ptr %ld607, ptr %ld608)
  %$t8128.addr = alloca ptr
  store ptr %cr609, ptr %$t8128.addr
  %ld610 = load ptr, ptr %$t8128.addr
  %sl611 = call ptr @march_string_lit(ptr @.str134, i64 13)
  %cr612 = call ptr @march_string_concat(ptr %ld610, ptr %sl611)
  %$t8129.addr = alloca ptr
  store ptr %cr612, ptr %$t8129.addr
  %ld613 = load ptr, ptr %$t8129.addr
  %sl614 = call ptr @march_string_lit(ptr @.str135, i64 80)
  %cr615 = call ptr @march_string_concat(ptr %ld613, ptr %sl614)
  %$t8130.addr = alloca ptr
  store ptr %cr615, ptr %$t8130.addr
  %ld616 = load ptr, ptr %$t8130.addr
  %sl617 = call ptr @march_string_lit(ptr @.str136, i64 44)
  %cr618 = call ptr @march_string_concat(ptr %ld616, ptr %sl617)
  %$t8131.addr = alloca ptr
  store ptr %cr618, ptr %$t8131.addr
  %ld619 = load ptr, ptr %$t8131.addr
  %sl620 = call ptr @march_string_lit(ptr @.str137, i64 7)
  %cr621 = call ptr @march_string_concat(ptr %ld619, ptr %sl620)
  %$t8132.addr = alloca ptr
  store ptr %cr621, ptr %$t8132.addr
  %ld622 = load ptr, ptr %$t8132.addr
  %sl623 = call ptr @march_string_lit(ptr @.str138, i64 7)
  %cr624 = call ptr @march_string_concat(ptr %ld622, ptr %sl623)
  %$t8133.addr = alloca ptr
  store ptr %cr624, ptr %$t8133.addr
  %ld625 = load ptr, ptr %$t8133.addr
  %sl626 = call ptr @march_string_lit(ptr @.str139, i64 34)
  %cr627 = call ptr @march_string_concat(ptr %ld625, ptr %sl626)
  %$t8134.addr = alloca ptr
  store ptr %cr627, ptr %$t8134.addr
  %ld628 = load ptr, ptr %$t8134.addr
  %sl629 = call ptr @march_string_lit(ptr @.str140, i64 47)
  %cr630 = call ptr @march_string_concat(ptr %ld628, ptr %sl629)
  %$t8135.addr = alloca ptr
  store ptr %cr630, ptr %$t8135.addr
  %ld631 = load ptr, ptr %$t8135.addr
  %sl632 = call ptr @march_string_lit(ptr @.str141, i64 28)
  %cr633 = call ptr @march_string_concat(ptr %ld631, ptr %sl632)
  %$t8136.addr = alloca ptr
  store ptr %cr633, ptr %$t8136.addr
  %ld634 = load ptr, ptr %$t8136.addr
  %sl635 = call ptr @march_string_lit(ptr @.str142, i64 89)
  %cr636 = call ptr @march_string_concat(ptr %ld634, ptr %sl635)
  %$t8137.addr = alloca ptr
  store ptr %cr636, ptr %$t8137.addr
  %ld637 = load ptr, ptr %$t8137.addr
  %sl638 = call ptr @march_string_lit(ptr @.str143, i64 7)
  %cr639 = call ptr @march_string_concat(ptr %ld637, ptr %sl638)
  %$t8138.addr = alloca ptr
  store ptr %cr639, ptr %$t8138.addr
  %ld640 = load ptr, ptr %$t8138.addr
  %sl641 = call ptr @march_string_lit(ptr @.str144, i64 7)
  %cr642 = call ptr @march_string_concat(ptr %ld640, ptr %sl641)
  %$t8139.addr = alloca ptr
  store ptr %cr642, ptr %$t8139.addr
  %ld643 = load ptr, ptr %$t8139.addr
  %sl644 = call ptr @march_string_lit(ptr @.str145, i64 56)
  %cr645 = call ptr @march_string_concat(ptr %ld643, ptr %sl644)
  %$t8140.addr = alloca ptr
  store ptr %cr645, ptr %$t8140.addr
  %ld646 = load ptr, ptr %$t8140.addr
  %sl647 = call ptr @march_string_lit(ptr @.str146, i64 27)
  %cr648 = call ptr @march_string_concat(ptr %ld646, ptr %sl647)
  %$t8141.addr = alloca ptr
  store ptr %cr648, ptr %$t8141.addr
  %ld649 = load ptr, ptr %$t8141.addr
  %sl650 = call ptr @march_string_lit(ptr @.str147, i64 30)
  %cr651 = call ptr @march_string_concat(ptr %ld649, ptr %sl650)
  %$t8142.addr = alloca ptr
  store ptr %cr651, ptr %$t8142.addr
  %ld652 = load ptr, ptr %$t8142.addr
  %sl653 = call ptr @march_string_lit(ptr @.str148, i64 18)
  %cr654 = call ptr @march_string_concat(ptr %ld652, ptr %sl653)
  %$t8143.addr = alloca ptr
  store ptr %cr654, ptr %$t8143.addr
  %ld655 = load ptr, ptr %$t8143.addr
  %sl656 = call ptr @march_string_lit(ptr @.str149, i64 38)
  %cr657 = call ptr @march_string_concat(ptr %ld655, ptr %sl656)
  %$t8144.addr = alloca ptr
  store ptr %cr657, ptr %$t8144.addr
  %ld658 = load ptr, ptr %$t8144.addr
  %sl659 = call ptr @march_string_lit(ptr @.str150, i64 86)
  %cr660 = call ptr @march_string_concat(ptr %ld658, ptr %sl659)
  %$t8145.addr = alloca ptr
  store ptr %cr660, ptr %$t8145.addr
  %ld661 = load ptr, ptr %$t8145.addr
  %sl662 = call ptr @march_string_lit(ptr @.str151, i64 33)
  %cr663 = call ptr @march_string_concat(ptr %ld661, ptr %sl662)
  %$t8146.addr = alloca ptr
  store ptr %cr663, ptr %$t8146.addr
  %ld664 = load ptr, ptr %$t8146.addr
  %ld665 = load ptr, ptr %pascal.addr
  %cr666 = call ptr @march_string_concat(ptr %ld664, ptr %ld665)
  %$t8147.addr = alloca ptr
  store ptr %cr666, ptr %$t8147.addr
  %ld667 = load ptr, ptr %$t8147.addr
  %sl668 = call ptr @march_string_lit(ptr @.str152, i64 15)
  %cr669 = call ptr @march_string_concat(ptr %ld667, ptr %sl668)
  %$t8148.addr = alloca ptr
  store ptr %cr669, ptr %$t8148.addr
  %ld670 = load ptr, ptr %$t8148.addr
  %sl671 = call ptr @march_string_lit(ptr @.str153, i64 61)
  %cr672 = call ptr @march_string_concat(ptr %ld670, ptr %sl671)
  %$t8149.addr = alloca ptr
  store ptr %cr672, ptr %$t8149.addr
  %ld673 = load ptr, ptr %$t8149.addr
  %sl674 = call ptr @march_string_lit(ptr @.str154, i64 19)
  %cr675 = call ptr @march_string_concat(ptr %ld673, ptr %sl674)
  %$t8150.addr = alloca ptr
  store ptr %cr675, ptr %$t8150.addr
  %ld676 = load ptr, ptr %$t8150.addr
  %sl677 = call ptr @march_string_lit(ptr @.str155, i64 18)
  %cr678 = call ptr @march_string_concat(ptr %ld676, ptr %sl677)
  %$t8151.addr = alloca ptr
  store ptr %cr678, ptr %$t8151.addr
  %ld679 = load ptr, ptr %$t8151.addr
  %sl680 = call ptr @march_string_lit(ptr @.str156, i64 76)
  %cr681 = call ptr @march_string_concat(ptr %ld679, ptr %sl680)
  %$t8152.addr = alloca ptr
  store ptr %cr681, ptr %$t8152.addr
  %ld682 = load ptr, ptr %$t8152.addr
  %sl683 = call ptr @march_string_lit(ptr @.str157, i64 47)
  %cr684 = call ptr @march_string_concat(ptr %ld682, ptr %sl683)
  %$t8153.addr = alloca ptr
  store ptr %cr684, ptr %$t8153.addr
  %ld685 = load ptr, ptr %$t8153.addr
  %sl686 = call ptr @march_string_lit(ptr @.str158, i64 19)
  %cr687 = call ptr @march_string_concat(ptr %ld685, ptr %sl686)
  %$t8154.addr = alloca ptr
  store ptr %cr687, ptr %$t8154.addr
  %ld688 = load ptr, ptr %$t8154.addr
  %sl689 = call ptr @march_string_lit(ptr @.str159, i64 16)
  %cr690 = call ptr @march_string_concat(ptr %ld688, ptr %sl689)
  %$t8155.addr = alloca ptr
  store ptr %cr690, ptr %$t8155.addr
  %ld691 = load ptr, ptr %$t8155.addr
  %sl692 = call ptr @march_string_lit(ptr @.str160, i64 7)
  %cr693 = call ptr @march_string_concat(ptr %ld691, ptr %sl692)
  %$t8156.addr = alloca ptr
  store ptr %cr693, ptr %$t8156.addr
  %ld694 = load ptr, ptr %$t8156.addr
  %sl695 = call ptr @march_string_lit(ptr @.str161, i64 4)
  %cr696 = call ptr @march_string_concat(ptr %ld694, ptr %sl695)
  ret ptr %cr696
}

define ptr @counter_island(ptr nonnull dereferenceable(16) %_pascal.arg) {
entry:
  %_pascal.addr = alloca ptr
  store ptr %_pascal.arg, ptr %_pascal.addr
  %sl697 = call ptr @march_string_lit(ptr @.str162, i64 41)
  %sl698 = call ptr @march_string_lit(ptr @.str163, i64 3)
  %cr699 = call ptr @march_string_concat(ptr %sl697, ptr %sl698)
  %$t8157.addr = alloca ptr
  store ptr %cr699, ptr %$t8157.addr
  %ld700 = load ptr, ptr %$t8157.addr
  %sl701 = call ptr @march_string_lit(ptr @.str164, i64 20)
  %cr702 = call ptr @march_string_concat(ptr %ld700, ptr %sl701)
  %$t8158.addr = alloca ptr
  store ptr %cr702, ptr %$t8158.addr
  %ld703 = load ptr, ptr %$t8158.addr
  %sl704 = call ptr @march_string_lit(ptr @.str165, i64 96)
  %cr705 = call ptr @march_string_concat(ptr %ld703, ptr %sl704)
  %$t8159.addr = alloca ptr
  store ptr %cr705, ptr %$t8159.addr
  %ld706 = load ptr, ptr %$t8159.addr
  %sl707 = call ptr @march_string_lit(ptr @.str166, i64 16)
  %cr708 = call ptr @march_string_concat(ptr %ld706, ptr %sl707)
  %$t8160.addr = alloca ptr
  store ptr %cr708, ptr %$t8160.addr
  %ld709 = load ptr, ptr %$t8160.addr
  %sl710 = call ptr @march_string_lit(ptr @.str167, i64 32)
  %cr711 = call ptr @march_string_concat(ptr %ld709, ptr %sl710)
  %$t8161.addr = alloca ptr
  store ptr %cr711, ptr %$t8161.addr
  %ld712 = load ptr, ptr %$t8161.addr
  %sl713 = call ptr @march_string_lit(ptr @.str168, i64 45)
  %cr714 = call ptr @march_string_concat(ptr %ld712, ptr %sl713)
  %$t8162.addr = alloca ptr
  store ptr %cr714, ptr %$t8162.addr
  %ld715 = load ptr, ptr %$t8162.addr
  %sl716 = call ptr @march_string_lit(ptr @.str169, i64 40)
  %cr717 = call ptr @march_string_concat(ptr %ld715, ptr %sl716)
  %$t8163.addr = alloca ptr
  store ptr %cr717, ptr %$t8163.addr
  %ld718 = load ptr, ptr %$t8163.addr
  %sl719 = call ptr @march_string_lit(ptr @.str170, i64 35)
  %cr720 = call ptr @march_string_concat(ptr %ld718, ptr %sl719)
  %$t8164.addr = alloca ptr
  store ptr %cr720, ptr %$t8164.addr
  %ld721 = load ptr, ptr %$t8164.addr
  %sl722 = call ptr @march_string_lit(ptr @.str171, i64 62)
  %cr723 = call ptr @march_string_concat(ptr %ld721, ptr %sl722)
  %$t8165.addr = alloca ptr
  store ptr %cr723, ptr %$t8165.addr
  %ld724 = load ptr, ptr %$t8165.addr
  %sl725 = call ptr @march_string_lit(ptr @.str172, i64 73)
  %cr726 = call ptr @march_string_concat(ptr %ld724, ptr %sl725)
  %$t8166.addr = alloca ptr
  store ptr %cr726, ptr %$t8166.addr
  %ld727 = load ptr, ptr %$t8166.addr
  %sl728 = call ptr @march_string_lit(ptr @.str173, i64 60)
  %cr729 = call ptr @march_string_concat(ptr %ld727, ptr %sl728)
  %$t8167.addr = alloca ptr
  store ptr %cr729, ptr %$t8167.addr
  %ld730 = load ptr, ptr %$t8167.addr
  %sl731 = call ptr @march_string_lit(ptr @.str174, i64 13)
  %cr732 = call ptr @march_string_concat(ptr %ld730, ptr %sl731)
  %$t8168.addr = alloca ptr
  store ptr %cr732, ptr %$t8168.addr
  %ld733 = load ptr, ptr %$t8168.addr
  %sl734 = call ptr @march_string_lit(ptr @.str175, i64 7)
  %cr735 = call ptr @march_string_concat(ptr %ld733, ptr %sl734)
  %$t8169.addr = alloca ptr
  store ptr %cr735, ptr %$t8169.addr
  %ld736 = load ptr, ptr %$t8169.addr
  %sl737 = call ptr @march_string_lit(ptr @.str176, i64 64)
  %cr738 = call ptr @march_string_concat(ptr %ld736, ptr %sl737)
  %$t8170.addr = alloca ptr
  store ptr %cr738, ptr %$t8170.addr
  %ld739 = load ptr, ptr %$t8170.addr
  %sl740 = call ptr @march_string_lit(ptr @.str177, i64 40)
  %cr741 = call ptr @march_string_concat(ptr %ld739, ptr %sl740)
  %$t8171.addr = alloca ptr
  store ptr %cr741, ptr %$t8171.addr
  %ld742 = load ptr, ptr %$t8171.addr
  %sl743 = call ptr @march_string_lit(ptr @.str178, i64 38)
  %cr744 = call ptr @march_string_concat(ptr %ld742, ptr %sl743)
  %$t8172.addr = alloca ptr
  store ptr %cr744, ptr %$t8172.addr
  %ld745 = load ptr, ptr %$t8172.addr
  %sl746 = call ptr @march_string_lit(ptr @.str179, i64 35)
  %cr747 = call ptr @march_string_concat(ptr %ld745, ptr %sl746)
  %$t8173.addr = alloca ptr
  store ptr %cr747, ptr %$t8173.addr
  %ld748 = load ptr, ptr %$t8173.addr
  %sl749 = call ptr @march_string_lit(ptr @.str180, i64 35)
  %cr750 = call ptr @march_string_concat(ptr %ld748, ptr %sl749)
  %$t8174.addr = alloca ptr
  store ptr %cr750, ptr %$t8174.addr
  %ld751 = load ptr, ptr %$t8174.addr
  %sl752 = call ptr @march_string_lit(ptr @.str181, i64 30)
  %cr753 = call ptr @march_string_concat(ptr %ld751, ptr %sl752)
  %$t8175.addr = alloca ptr
  store ptr %cr753, ptr %$t8175.addr
  %ld754 = load ptr, ptr %$t8175.addr
  %sl755 = call ptr @march_string_lit(ptr @.str182, i64 10)
  %cr756 = call ptr @march_string_concat(ptr %ld754, ptr %sl755)
  %$t8176.addr = alloca ptr
  store ptr %cr756, ptr %$t8176.addr
  %ld757 = load ptr, ptr %$t8176.addr
  %sl758 = call ptr @march_string_lit(ptr @.str183, i64 53)
  %cr759 = call ptr @march_string_concat(ptr %ld757, ptr %sl758)
  %$t8177.addr = alloca ptr
  store ptr %cr759, ptr %$t8177.addr
  %ld760 = load ptr, ptr %$t8177.addr
  %sl761 = call ptr @march_string_lit(ptr @.str184, i64 7)
  %cr762 = call ptr @march_string_concat(ptr %ld760, ptr %sl761)
  %$t8178.addr = alloca ptr
  store ptr %cr762, ptr %$t8178.addr
  %ld763 = load ptr, ptr %$t8178.addr
  %sl764 = call ptr @march_string_lit(ptr @.str185, i64 48)
  %cr765 = call ptr @march_string_concat(ptr %ld763, ptr %sl764)
  %$t8179.addr = alloca ptr
  store ptr %cr765, ptr %$t8179.addr
  %ld766 = load ptr, ptr %$t8179.addr
  %sl767 = call ptr @march_string_lit(ptr @.str186, i64 36)
  %cr768 = call ptr @march_string_concat(ptr %ld766, ptr %sl767)
  %$t8180.addr = alloca ptr
  store ptr %cr768, ptr %$t8180.addr
  %ld769 = load ptr, ptr %$t8180.addr
  %sl770 = call ptr @march_string_lit(ptr @.str187, i64 16)
  %cr771 = call ptr @march_string_concat(ptr %ld769, ptr %sl770)
  %$t8181.addr = alloca ptr
  store ptr %cr771, ptr %$t8181.addr
  %ld772 = load ptr, ptr %$t8181.addr
  %sl773 = call ptr @march_string_lit(ptr @.str188, i64 36)
  %cr774 = call ptr @march_string_concat(ptr %ld772, ptr %sl773)
  %$t8182.addr = alloca ptr
  store ptr %cr774, ptr %$t8182.addr
  %ld775 = load ptr, ptr %$t8182.addr
  %sl776 = call ptr @march_string_lit(ptr @.str189, i64 32)
  %cr777 = call ptr @march_string_concat(ptr %ld775, ptr %sl776)
  %$t8183.addr = alloca ptr
  store ptr %cr777, ptr %$t8183.addr
  %ld778 = load ptr, ptr %$t8183.addr
  %sl779 = call ptr @march_string_lit(ptr @.str190, i64 19)
  %cr780 = call ptr @march_string_concat(ptr %ld778, ptr %sl779)
  %$t8184.addr = alloca ptr
  store ptr %cr780, ptr %$t8184.addr
  %ld781 = load ptr, ptr %$t8184.addr
  %sl782 = call ptr @march_string_lit(ptr @.str191, i64 10)
  %cr783 = call ptr @march_string_concat(ptr %ld781, ptr %sl782)
  %$t8185.addr = alloca ptr
  store ptr %cr783, ptr %$t8185.addr
  %ld784 = load ptr, ptr %$t8185.addr
  %sl785 = call ptr @march_string_lit(ptr @.str192, i64 8)
  %cr786 = call ptr @march_string_concat(ptr %ld784, ptr %sl785)
  %$t8186.addr = alloca ptr
  store ptr %cr786, ptr %$t8186.addr
  %ld787 = load ptr, ptr %$t8186.addr
  %sl788 = call ptr @march_string_lit(ptr @.str193, i64 16)
  %cr789 = call ptr @march_string_concat(ptr %ld787, ptr %sl788)
  %$t8187.addr = alloca ptr
  store ptr %cr789, ptr %$t8187.addr
  %ld790 = load ptr, ptr %$t8187.addr
  %sl791 = call ptr @march_string_lit(ptr @.str194, i64 8)
  %cr792 = call ptr @march_string_concat(ptr %ld790, ptr %sl791)
  %$t8188.addr = alloca ptr
  store ptr %cr792, ptr %$t8188.addr
  %ld793 = load ptr, ptr %$t8188.addr
  %sl794 = call ptr @march_string_lit(ptr @.str195, i64 7)
  %cr795 = call ptr @march_string_concat(ptr %ld793, ptr %sl794)
  %$t8189.addr = alloca ptr
  store ptr %cr795, ptr %$t8189.addr
  %ld796 = load ptr, ptr %$t8189.addr
  %sl797 = call ptr @march_string_lit(ptr @.str196, i64 42)
  %cr798 = call ptr @march_string_concat(ptr %ld796, ptr %sl797)
  %$t8190.addr = alloca ptr
  store ptr %cr798, ptr %$t8190.addr
  %ld799 = load ptr, ptr %$t8190.addr
  %sl800 = call ptr @march_string_lit(ptr @.str197, i64 15)
  %cr801 = call ptr @march_string_concat(ptr %ld799, ptr %sl800)
  %$t8191.addr = alloca ptr
  store ptr %cr801, ptr %$t8191.addr
  %ld802 = load ptr, ptr %$t8191.addr
  %sl803 = call ptr @march_string_lit(ptr @.str198, i64 33)
  %cr804 = call ptr @march_string_concat(ptr %ld802, ptr %sl803)
  %$t8192.addr = alloca ptr
  store ptr %cr804, ptr %$t8192.addr
  %ld805 = load ptr, ptr %$t8192.addr
  %sl806 = call ptr @march_string_lit(ptr @.str199, i64 19)
  %cr807 = call ptr @march_string_concat(ptr %ld805, ptr %sl806)
  %$t8193.addr = alloca ptr
  store ptr %cr807, ptr %$t8193.addr
  %ld808 = load ptr, ptr %$t8193.addr
  %sl809 = call ptr @march_string_lit(ptr @.str200, i64 8)
  %cr810 = call ptr @march_string_concat(ptr %ld808, ptr %sl809)
  %$t8194.addr = alloca ptr
  store ptr %cr810, ptr %$t8194.addr
  %ld811 = load ptr, ptr %$t8194.addr
  %sl812 = call ptr @march_string_lit(ptr @.str201, i64 7)
  %cr813 = call ptr @march_string_concat(ptr %ld811, ptr %sl812)
  %$t8195.addr = alloca ptr
  store ptr %cr813, ptr %$t8195.addr
  %ld814 = load ptr, ptr %$t8195.addr
  %sl815 = call ptr @march_string_lit(ptr @.str202, i64 4)
  %cr816 = call ptr @march_string_concat(ptr %ld814, ptr %sl815)
  ret ptr %cr816
}

define ptr @app_css() {
entry:
  %sl817 = call ptr @march_string_lit(ptr @.str203, i64 52)
  %sl818 = call ptr @march_string_lit(ptr @.str204, i64 7)
  %cr819 = call ptr @march_string_concat(ptr %sl817, ptr %sl818)
  %$t8196.addr = alloca ptr
  store ptr %cr819, ptr %$t8196.addr
  %ld820 = load ptr, ptr %$t8196.addr
  %sl821 = call ptr @march_string_lit(ptr @.str205, i64 38)
  %cr822 = call ptr @march_string_concat(ptr %ld820, ptr %sl821)
  %$t8197.addr = alloca ptr
  store ptr %cr822, ptr %$t8197.addr
  %ld823 = load ptr, ptr %$t8197.addr
  %sl824 = call ptr @march_string_lit(ptr @.str206, i64 20)
  %cr825 = call ptr @march_string_concat(ptr %ld823, ptr %sl824)
  %$t8198.addr = alloca ptr
  store ptr %cr825, ptr %$t8198.addr
  %ld826 = load ptr, ptr %$t8198.addr
  %sl827 = call ptr @march_string_lit(ptr @.str207, i64 18)
  %cr828 = call ptr @march_string_concat(ptr %ld826, ptr %sl827)
  %$t8199.addr = alloca ptr
  store ptr %cr828, ptr %$t8199.addr
  %ld829 = load ptr, ptr %$t8199.addr
  %sl830 = call ptr @march_string_lit(ptr @.str208, i64 17)
  %cr831 = call ptr @march_string_concat(ptr %ld829, ptr %sl830)
  %$t8200.addr = alloca ptr
  store ptr %cr831, ptr %$t8200.addr
  %ld832 = load ptr, ptr %$t8200.addr
  %sl833 = call ptr @march_string_lit(ptr @.str209, i64 18)
  %cr834 = call ptr @march_string_concat(ptr %ld832, ptr %sl833)
  %$t8201.addr = alloca ptr
  store ptr %cr834, ptr %$t8201.addr
  %ld835 = load ptr, ptr %$t8201.addr
  %sl836 = call ptr @march_string_lit(ptr @.str210, i64 3)
  %cr837 = call ptr @march_string_concat(ptr %ld835, ptr %sl836)
  %$t8202.addr = alloca ptr
  store ptr %cr837, ptr %$t8202.addr
  %ld838 = load ptr, ptr %$t8202.addr
  %sl839 = call ptr @march_string_lit(ptr @.str211, i64 29)
  %cr840 = call ptr @march_string_concat(ptr %ld838, ptr %sl839)
  %$t8203.addr = alloca ptr
  store ptr %cr840, ptr %$t8203.addr
  %ld841 = load ptr, ptr %$t8203.addr
  %sl842 = call ptr @march_string_lit(ptr @.str212, i64 69)
  %cr843 = call ptr @march_string_concat(ptr %ld841, ptr %sl842)
  %$t8204.addr = alloca ptr
  store ptr %cr843, ptr %$t8204.addr
  %ld844 = load ptr, ptr %$t8204.addr
  %sl845 = call ptr @march_string_lit(ptr @.str213, i64 45)
  %cr846 = call ptr @march_string_concat(ptr %ld844, ptr %sl845)
  %$t8205.addr = alloca ptr
  store ptr %cr846, ptr %$t8205.addr
  %ld847 = load ptr, ptr %$t8205.addr
  %sl848 = call ptr @march_string_lit(ptr @.str214, i64 11)
  %cr849 = call ptr @march_string_concat(ptr %ld847, ptr %sl848)
  %$t8206.addr = alloca ptr
  store ptr %cr849, ptr %$t8206.addr
  %ld850 = load ptr, ptr %$t8206.addr
  %sl851 = call ptr @march_string_lit(ptr @.str215, i64 24)
  %cr852 = call ptr @march_string_concat(ptr %ld850, ptr %sl851)
  %$t8207.addr = alloca ptr
  store ptr %cr852, ptr %$t8207.addr
  %ld853 = load ptr, ptr %$t8207.addr
  %sl854 = call ptr @march_string_lit(ptr @.str216, i64 23)
  %cr855 = call ptr @march_string_concat(ptr %ld853, ptr %sl854)
  %$t8208.addr = alloca ptr
  store ptr %cr855, ptr %$t8208.addr
  %ld856 = load ptr, ptr %$t8208.addr
  %sl857 = call ptr @march_string_lit(ptr @.str217, i64 16)
  %cr858 = call ptr @march_string_concat(ptr %ld856, ptr %sl857)
  %$t8209.addr = alloca ptr
  store ptr %cr858, ptr %$t8209.addr
  %ld859 = load ptr, ptr %$t8209.addr
  %sl860 = call ptr @march_string_lit(ptr @.str218, i64 21)
  %cr861 = call ptr @march_string_concat(ptr %ld859, ptr %sl860)
  %$t8210.addr = alloca ptr
  store ptr %cr861, ptr %$t8210.addr
  %ld862 = load ptr, ptr %$t8210.addr
  %sl863 = call ptr @march_string_lit(ptr @.str219, i64 3)
  %cr864 = call ptr @march_string_concat(ptr %ld862, ptr %sl863)
  %$t8211.addr = alloca ptr
  store ptr %cr864, ptr %$t8211.addr
  %ld865 = load ptr, ptr %$t8211.addr
  %sl866 = call ptr @march_string_lit(ptr @.str220, i64 18)
  %cr867 = call ptr @march_string_concat(ptr %ld865, ptr %sl866)
  %$t8212.addr = alloca ptr
  store ptr %cr867, ptr %$t8212.addr
  %ld868 = load ptr, ptr %$t8212.addr
  %sl869 = call ptr @march_string_lit(ptr @.str221, i64 21)
  %cr870 = call ptr @march_string_concat(ptr %ld868, ptr %sl869)
  %$t8213.addr = alloca ptr
  store ptr %cr870, ptr %$t8213.addr
  %ld871 = load ptr, ptr %$t8213.addr
  %sl872 = call ptr @march_string_lit(ptr @.str222, i64 17)
  %cr873 = call ptr @march_string_concat(ptr %ld871, ptr %sl872)
  %$t8214.addr = alloca ptr
  store ptr %cr873, ptr %$t8214.addr
  %ld874 = load ptr, ptr %$t8214.addr
  %sl875 = call ptr @march_string_lit(ptr @.str223, i64 18)
  %cr876 = call ptr @march_string_concat(ptr %ld874, ptr %sl875)
  %$t8215.addr = alloca ptr
  store ptr %cr876, ptr %$t8215.addr
  %ld877 = load ptr, ptr %$t8215.addr
  %sl878 = call ptr @march_string_lit(ptr @.str224, i64 26)
  %cr879 = call ptr @march_string_concat(ptr %ld877, ptr %sl878)
  %$t8216.addr = alloca ptr
  store ptr %cr879, ptr %$t8216.addr
  %ld880 = load ptr, ptr %$t8216.addr
  %sl881 = call ptr @march_string_lit(ptr @.str225, i64 22)
  %cr882 = call ptr @march_string_concat(ptr %ld880, ptr %sl881)
  %$t8217.addr = alloca ptr
  store ptr %cr882, ptr %$t8217.addr
  %ld883 = load ptr, ptr %$t8217.addr
  %sl884 = call ptr @march_string_lit(ptr @.str226, i64 19)
  %cr885 = call ptr @march_string_concat(ptr %ld883, ptr %sl884)
  %$t8218.addr = alloca ptr
  store ptr %cr885, ptr %$t8218.addr
  %ld886 = load ptr, ptr %$t8218.addr
  %sl887 = call ptr @march_string_lit(ptr @.str227, i64 21)
  %cr888 = call ptr @march_string_concat(ptr %ld886, ptr %sl887)
  %$t8219.addr = alloca ptr
  store ptr %cr888, ptr %$t8219.addr
  %ld889 = load ptr, ptr %$t8219.addr
  %sl890 = call ptr @march_string_lit(ptr @.str228, i64 3)
  %cr891 = call ptr @march_string_concat(ptr %ld889, ptr %sl890)
  %$t8220.addr = alloca ptr
  store ptr %cr891, ptr %$t8220.addr
  %ld892 = load ptr, ptr %$t8220.addr
  %sl893 = call ptr @march_string_lit(ptr @.str229, i64 47)
  %cr894 = call ptr @march_string_concat(ptr %ld892, ptr %sl893)
  ret ptr %cr894
}

define ptr @test_module(ptr nonnull dereferenceable(16) %_name.arg, ptr nonnull dereferenceable(16) %pascal.arg) {
entry:
  %_name.addr = alloca ptr
  store ptr %_name.arg, ptr %_name.addr
  %pascal.addr = alloca ptr
  store ptr %pascal.arg, ptr %pascal.addr
  %sl895 = call ptr @march_string_lit(ptr @.str230, i64 4)
  %ld896 = load ptr, ptr %pascal.addr
  %cr897 = call ptr @march_string_concat(ptr %sl895, ptr %ld896)
  %$t8221.addr = alloca ptr
  store ptr %cr897, ptr %$t8221.addr
  %ld898 = load ptr, ptr %$t8221.addr
  %sl899 = call ptr @march_string_lit(ptr @.str231, i64 9)
  %cr900 = call ptr @march_string_concat(ptr %ld898, ptr %sl899)
  %$t8222.addr = alloca ptr
  store ptr %cr900, ptr %$t8222.addr
  %ld901 = load ptr, ptr %$t8222.addr
  %sl902 = call ptr @march_string_lit(ptr @.str232, i64 18)
  %cr903 = call ptr @march_string_concat(ptr %ld901, ptr %sl902)
  %$t8223.addr = alloca ptr
  store ptr %cr903, ptr %$t8223.addr
  %ld904 = load ptr, ptr %$t8223.addr
  %sl905 = call ptr @march_string_lit(ptr @.str233, i64 32)
  %cr906 = call ptr @march_string_concat(ptr %ld904, ptr %sl905)
  %$t8224.addr = alloca ptr
  store ptr %cr906, ptr %$t8224.addr
  %ld907 = load ptr, ptr %$t8224.addr
  %sl908 = call ptr @march_string_lit(ptr @.str234, i64 41)
  %cr909 = call ptr @march_string_concat(ptr %ld907, ptr %sl908)
  %$t8225.addr = alloca ptr
  store ptr %cr909, ptr %$t8225.addr
  %ld910 = load ptr, ptr %$t8225.addr
  %sl911 = call ptr @march_string_lit(ptr @.str235, i64 49)
  %cr912 = call ptr @march_string_concat(ptr %ld910, ptr %sl911)
  %$t8226.addr = alloca ptr
  store ptr %cr912, ptr %$t8226.addr
  %ld913 = load ptr, ptr %$t8226.addr
  %sl914 = call ptr @march_string_lit(ptr @.str236, i64 42)
  %cr915 = call ptr @march_string_concat(ptr %ld913, ptr %sl914)
  %$t8227.addr = alloca ptr
  store ptr %cr915, ptr %$t8227.addr
  %ld916 = load ptr, ptr %$t8227.addr
  %sl917 = call ptr @march_string_lit(ptr @.str237, i64 9)
  %cr918 = call ptr @march_string_concat(ptr %ld916, ptr %sl917)
  %$t8228.addr = alloca ptr
  store ptr %cr918, ptr %$t8228.addr
  %ld919 = load ptr, ptr %$t8228.addr
  %sl920 = call ptr @march_string_lit(ptr @.str238, i64 40)
  %cr921 = call ptr @march_string_concat(ptr %ld919, ptr %sl920)
  %$t8229.addr = alloca ptr
  store ptr %cr921, ptr %$t8229.addr
  %ld922 = load ptr, ptr %$t8229.addr
  %sl923 = call ptr @march_string_lit(ptr @.str239, i64 66)
  %cr924 = call ptr @march_string_concat(ptr %ld922, ptr %sl923)
  %$t8230.addr = alloca ptr
  store ptr %cr924, ptr %$t8230.addr
  %ld925 = load ptr, ptr %$t8230.addr
  %sl926 = call ptr @march_string_lit(ptr @.str240, i64 42)
  %cr927 = call ptr @march_string_concat(ptr %ld925, ptr %sl926)
  %$t8231.addr = alloca ptr
  store ptr %cr927, ptr %$t8231.addr
  %ld928 = load ptr, ptr %$t8231.addr
  %sl929 = call ptr @march_string_lit(ptr @.str241, i64 9)
  %cr930 = call ptr @march_string_concat(ptr %ld928, ptr %sl929)
  %$t8232.addr = alloca ptr
  store ptr %cr930, ptr %$t8232.addr
  %ld931 = load ptr, ptr %$t8232.addr
  %sl932 = call ptr @march_string_lit(ptr @.str242, i64 40)
  %cr933 = call ptr @march_string_concat(ptr %ld931, ptr %sl932)
  %$t8233.addr = alloca ptr
  store ptr %cr933, ptr %$t8233.addr
  %ld934 = load ptr, ptr %$t8233.addr
  %sl935 = call ptr @march_string_lit(ptr @.str243, i64 66)
  %cr936 = call ptr @march_string_concat(ptr %ld934, ptr %sl935)
  %$t8234.addr = alloca ptr
  store ptr %cr936, ptr %$t8234.addr
  %ld937 = load ptr, ptr %$t8234.addr
  %sl938 = call ptr @march_string_lit(ptr @.str244, i64 42)
  %cr939 = call ptr @march_string_concat(ptr %ld937, ptr %sl938)
  %$t8235.addr = alloca ptr
  store ptr %cr939, ptr %$t8235.addr
  %ld940 = load ptr, ptr %$t8235.addr
  %sl941 = call ptr @march_string_lit(ptr @.str245, i64 9)
  %cr942 = call ptr @march_string_concat(ptr %ld940, ptr %sl941)
  %$t8236.addr = alloca ptr
  store ptr %cr942, ptr %$t8236.addr
  %ld943 = load ptr, ptr %$t8236.addr
  %sl944 = call ptr @march_string_lit(ptr @.str246, i64 7)
  %cr945 = call ptr @march_string_concat(ptr %ld943, ptr %sl944)
  %$t8237.addr = alloca ptr
  store ptr %cr945, ptr %$t8237.addr
  %ld946 = load ptr, ptr %$t8237.addr
  %sl947 = call ptr @march_string_lit(ptr @.str247, i64 4)
  %cr948 = call ptr @march_string_concat(ptr %ld946, ptr %sl947)
  ret ptr %cr948
}

declare void @march_process_argv_init(i32 %argc, ptr %argv_ptr)
define i32 @main(i32 %argc, ptr %argv_ptr) {
entry:
call void @march_process_argv_init(i32 %argc, ptr %argv_ptr)
call void @march_main()
call void @march_run_scheduler()
ret i32 0
}
