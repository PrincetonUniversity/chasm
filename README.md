# CHASM

## The problem of computer security

### Today’s computer systems are not secure. While some users believe their systems are secure if they run only trusted software, the protection provided by all the software security techniques can be circumvented if the underlying hardware is vulnerable. So in order to really secure your system, you need to have not only trusted software but also trustworthy hardware. 

## The CHASM Contaiment Security Architecture

### The proposed work addresses these problems using a small, separate, and simple module of trusted hardware that verifies certain actions of the system. To provide users with key assurances, this module need only verify that each trusted program was executed correctly and that only correctly executed trusted code may send data to the outside world. The module is simple enough to be verified and manufactured at a trusted fabrication plant using technology generations old.

## How CHAMS stacks up against other FPGA-based processors (secure & non-secure)

![CHASM Comparison](/images/comparison.png)

### This table compares the proposed work with state-of-the-art FPGA designs. CHASM yields the highest performance thanks to its stall-free design (all dependences resolved with the execution trace provided by the monitored untrusted systems), does not require any speculation (not susceptible to attacks related to observed speculative execution), and is the simplest in terms of lines of code.

## The CHASM flow

![CHASM Design](/images/containmentflow.png)

### This diagram shows the high-level architecture of the CHASM architectures. Trusted applications gets compiled through our custom toolchain and communicates its proof to the FPGA system when executed. The FPGA system verifies the execution and only allows output on correct execution of trusted code.

## The RTL Source Code for the FPGA system

### This Github Repo contains the design of the Sentry Control and the Sentry on the FPGA.
#### /trustguard/toplevel: top level instantiation of the FPGA system
#### /trustguard/sentrycontrol: RTL source for the Sentry Control
#### /trustguard/sentry: RTL source for the Sentry
#### /trustguard/utils: Various Utility RTL sources
#### /trustguard/uncore: shared uncore design RTL sources
#### /trustguard/Multiported-RAM: Multiported memory implementation used by the CHASM architecture
