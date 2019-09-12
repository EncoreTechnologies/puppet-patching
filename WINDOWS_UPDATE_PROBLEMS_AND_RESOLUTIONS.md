# Windows update HRESULT problems and fixes

- hresult: 0x8024402C 
  possibilities:
    - problem: a proxy setting in the system that is broken
      solutions:
       - fix the proxy config by going to IE -> Internet Options -> Connections
       - either set proxy to "auto detect" or fix the proxy server
    - problem: DNS is broken on the server and can't ping / access the WSUS server by name
      troubleshooting: try to ping the WSUS server by hostname
      solutions: 
        - fix DNS so you can ping the WSUS server
        - could be bad DNS on the NIC
        - could be bad firewall policy on the host
        - could be bad firewall policy on the network
- hresult: 0x8024000E
  possibilities:
    - problem: windows update cache is corrupt
      solutions:
        - clean the windows update cache: bolt task run patching::cache_remove
      
