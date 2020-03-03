# CHASM

## The Problem of System Security

Today’s computer systems are not secure. While some users believe their systems are secure as long as they run only trusted software, the protection provided by all the software security techniques can be circumvented if the underlying hardware is vulnerable. To truly secure a computer system, one need to run trusted software on top of trustworthy hardware. 

## The CHASM Contaiment Security Architecture

The proposed work addresses the problem of securing systems using a simple and pluggable gatekeeping hardware module (implemented on a FPGA), called the Sentry. The Sentry bridges a physical gap between the untrusted system and its external interfaces. It ensures that any external communication of the protected system is the result of correct execution of trusted software. The module is simple enough to be verified and manufactured at a trusted fabrication plant using technology generations old.

The original idea behind this work is described in the ASPLOS 2019 paper titled "Architectural Supportfor Containment-based Security" by Zhang et al. (https://liberty.princeton.edu/Publications/asplos19_trustguard.pdf).

## The CHASM Architecture

![CHASM Design](/images/containmentflow.png)

This diagram shows the high-level architecture of CHASM. The Sentry cannot independently execute programs. Instead, to check program execution it relies on information sent by the processor and untrusted control components on the FPGA. Thus, the Sentry avoids much of the complexity of aggressive processor optimizations. The Sentry detects any erroneous or malicious behavior by untrusted components without trusting any information sent by the untrusted components. It does so using a combination of functional unit re-execution and a cryptographic memory integrity scheme.

## How CHAMS stacks up against other FPGA-based processors (secure & non-secure)

![CHASM Comparison](/images/comparison.png)

This table compares the CHASM with state-of-the-art FPGA designs. CHASM yields the highest performance thanks to its stall-free design (all dependences resolved with the execution trace provided by the monitored untrusted systems), does not require any speculation (not susceptible to attacks related to observed speculative execution), and is the simplest in terms of lines of code.

## The RTL Source Code for the FPGA system

### This Github Repo contains the design of the Sentry Control and the Sentry on the FPGA.
/trustguard/toplevel: top level instantiation of the FPGA system

/trustguard/sentrycontrol: RTL source for the Sentry Control

/trustguard/sentry: RTL source for the Sentry

/trustguard/utils: Various Utility RTL sources

/trustguard/uncore: shared uncore design RTL sources

/trustguard/Multiported-RAM: Multiported memory implementation used by the CHASM architecture
