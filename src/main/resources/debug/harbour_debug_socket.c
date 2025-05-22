/* 
 * harbour_debug_socket.c
 * Auto-injected debug integration for Harbour applications
 * Place in: src/main/resources/debug/harbour_debug_socket.c
 */

#include "hbapi.h"
#include "hbvm.h"
#include "hbdebug.h"
#include "hbapigt.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

static int debug_socket = -1;
static int is_debugging = 0;

// Hook into Harbour VM debugger functions
static void harbour_debug_proc_level_entry(PHB_ITEM pproc) {
    if (is_debugging) {
        char buffer[1024];
        snprintf(buffer, sizeof(buffer), "STACK_ENTER\n%s\n", hb_itemGetCPtr(pproc));
        send(debug_socket, buffer, strlen(buffer), 0);
    }
}

static void harbour_debug_proc_level_exit(void) {
    if (is_debugging) {
        send(debug_socket, "STACK_EXIT\n", 11, 0);
    }
}

static void harbour_debug_line_hook(int line, const char *module) {
    if (is_debugging) {
        char buffer[1024];
        snprintf(buffer, sizeof(buffer), "LINE\n%s\n%d\n", module, line);
        send(debug_socket, buffer, strlen(buffer), 0);
        
        // Check for breakpoint or step command
        char response[256];
        ssize_t bytes = recv(debug_socket, response, sizeof(response)-1, 0);
        if (bytes > 0) {
            response[bytes] = '\0';
            if (strncmp(response, "BREAK", 5) == 0) {
                // Wait for continue command
                handle_debug_commands();
            }
        }
    }
}

static void handle_debug_commands(void) {
    while (1) {
        char recv_buffer[1024];
        ssize_t bytes = recv(debug_socket, recv_buffer, sizeof(recv_buffer)-1, 0);
        if (bytes <= 0) break;
        
        recv_buffer[bytes] = '\0';
        
        if (strncmp(recv_buffer, "RESUME", 6) == 0) {
            break;
        } else if (strncmp(recv_buffer, "VARIABLES", 9) == 0) {
            send_local_variables();
        } else if (strncmp(recv_buffer, "STACK", 5) == 0) {
            send_call_stack();
        }
    }
}

// Harbour startup hook
HB_FUNC_INIT( HB_DEBUG_SOCKET_INIT ) {
    char* debug_port_str = getenv("HARBOUR_DEBUG_PORT");
    if (!debug_port_str) return;
    
    int port = atoi(debug_port_str);
    if (port <= 0) return;
    
    struct sockaddr_in server_addr;
    debug_socket = socket(AF_INET, SOCK_STREAM, 0);
    
    if (debug_socket < 0) return;
    
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port);
    server_addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    
    if (connect(debug_socket, (struct sockaddr*)&server_addr, sizeof(server_addr)) == 0) {
        is_debugging = 1;
        
        // Hook into Harbour debugger callbacks
        hb_vmAtInit(harbour_debug_proc_level_entry, 
                    harbour_debug_proc_level_exit, 
                    harbour_debug_line_hook);
    }
}

// Harbour shutdown hook
HB_FUNC_EXIT( HB_DEBUG_SOCKET_EXIT ) {
    if (debug_socket >= 0) {
        send(debug_socket, "TERMINATED\n", 11, 0);
        close(debug_socket);
        debug_socket = -1;
        is_debugging = 0;
    }
}