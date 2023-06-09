/*****************************************************************************
 *     This file is part of USMA CS484.
 *****************************************************************************/

/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#define MCAST_ID 1
#define CPU_PORT 255
/*
  255 is confirmed for opennetworking/p4mn　(Mininet/Stratum on docker)
  192 is confirmed for WEDGE-100BF-32X (2 pipes device)
  320 is probably good for 4 pipes devices
*/

#define ETH_TYPE_ARP 0x0806
#define ETH_TYPE_VLAN 0x8100

typedef bit<9> egressSpec_t;
typedef bit<48> macAddr_t;

/**************************************************************************/
/**************************  Headers  *************************************/
/**************************************************************************/

@controller_header("packet_in")
header packet_in_header_t {
    bit<9> ingress_port;
    bit<7> _pad;
}

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16> etherType;
}

header vlan_t {
    bit<3> pcp;
    bit<1> cfi;
    bit<12> vid;
    bit<16> etherType;
}

struct metadata {
    bit<12> vid;
    bit<16> etherType;
    bit<4> _pad;
}

struct headers {
    vlan_t vlan;
    ethernet_t ethernet;
    packet_in_header_t packet_in;
}

/**************************************************************************/
/***************************  Parser  *************************************/
/**************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        meta.vid = 0;
        meta.etherType = hdr.ethernet.etherType;
        transition select(hdr.ethernet.etherType) {
            ETH_TYPE_VLAN: parse_vlan;
            default: accept;
        }
    }

    state parse_vlan {
        packet.extract(hdr.vlan);
        meta.vid = hdr.vlan.vid;
        meta.etherType = hdr.vlan.etherType;
        transition accept;
    }
}

/**************************************************************************/
/*********************  Checksum Verification  *****************************/
/**************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/**************************************************************************/
/***********************  Ingress Processing  *****************************/
/**************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    action forward(egressSpec_t port) {
        standard_metadata.egress_spec = port;
    }

    action flood() {
        standard_metadata.mcast_grp = MCAST_ID;
    }




    /**********************************************************************/
    /* Switch Table Logic - Begins ****************************************/
    /**********************************************************************/
    
    // TODO: Create a table that matches on the desitnation Ethernet address
    // and VLAN ID and forwards the packet to the right egress port (using 
    // `forward` action) based on the matching rule. If there is no match, 
    // it floods the packet by default (using the `flood` action).
    //
    // NOTE: please follow p4-src/bridge.p4 for a reference example on how 
    // to create a table.
    

    /**** ADD YOUR CODE HERE ... ****/
    table switch_table {
        key = {
            hdr.ethernet.dstAddr: exact;
            meta.vid: exact;
        }
        actions = {
            forward;
            flood;
        }
        size = 1024;
        default_action = flood;
    }
    

    /**********************************************************************/
    /* Switch Table Logic - Ends ****************************************/
    /**********************************************************************/



    
    apply {




        /**********************************************************************/
        /* Ingress Apply Logic - Begins ***************************************/
        /**********************************************************************/

        // TODO: Broadcast all ARP packets using the `flood` action; otherwise, 
        // apply the table you have created above.
        //
        // NOTE: please follow p4-src/bridge.p4 for a reference example on how to
        // apply tables and use if/else blocks.


        /**** ADD YOUR CODE HERE ... ****/

        
        if (meta.etherType == ETH_TYPE_ARP)
            flood();
        else
            switch_table.apply();
        
        /**********************************************************************/
        /* Ingress Apply Logic - Ends *****************************************/
        /**********************************************************************/




    }
}

/**************************************************************************/
/************************  Egress Processing  *****************************/
/**************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    action noop() {
        /* empty */
    }
    
    action drop() {
        mark_to_drop(standard_metadata);
    }

    action to_controller() {
        hdr.packet_in.setValid();
        hdr.packet_in.ingress_port = standard_metadata.ingress_port;
    }




    /**********************************************************************/
    /* VLAN Table Logic - Begins ****************************************/
    /**********************************************************************/
    
    // COMPLETED FOR YOU: a table that matches on the egress port and VLAN ID and
    // lets the matching packets pass (using the `noop` action); else drops 
    // them by default.
 
    

    table vlan_table {
        key = {
            standard_metadata.egress_port: exact;
            meta.vid: exact;
        }
        actions = {
            noop;
            drop;
        }
        size = 1024;
        default_action = drop;
    }

    /**********************************************************************/
    /* VLAN Table Logic - Ends ****************************************/
    /**********************************************************************/




    apply {




        /**********************************************************************/
        /* Egress Apply Logic - Begins ****************************************/
        /**********************************************************************/

        // TODO: (1) Prunes multicast packets going to out the ingress port to 
        // prevent loops. (2) Send a copy of the ARP packet to the controller 
        // for learning. (3)COMPLETED FOR YOU- Check if the VLAN header exists. If yes, then drop
        // packets not matching the egress port's VLAN ID using the VLAN table
        // created above.
        //
        // NOTE: please follow p4-src/bridge.p4 for a reference example on how to
        // apply tables and use if/else blocks.


        /**** ADD YOUR CODE HERE ... ****/
        //1 checks if MCAST_ID is set
        if (standard_metadata.egress_port == standard_metadata.ingress_port)
            drop();
        //2 sends ARP packets to controller

        if (standard_metadata.egress_port == CPU_PORT) {
            if (meta.etherType == ETH_TYPE_ARP)
                to_controller();
            else
                drop();
        }
        else {
            if (hdr.vlan.isValid())
                vlan_table.apply();
        }
            

        //3
        
        /**********************************************************************/
        /* Egress Apply Logic - Ends ******************************************/
        /**********************************************************************/




    }
}

/**************************************************************************/
/*********************  Checksum Computation  *****************************/
/**************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/**************************************************************************/
/**************************  Deparser  ************************************/
/**************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.packet_in);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.vlan);
    }
}

/**************************************************************************/
/***************************  Switch  *************************************/
/**************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
