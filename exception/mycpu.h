`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       33
    `define FS_TO_DS_BUS_WD 64
    `define DS_TO_ES_BUS_WD 136
    `define ES_TO_MS_BUS_WD 71
    `define MS_TO_WS_BUS_WD 70
    `define WS_TO_RF_BUS_WD 38

    // exception part
    `define CP0_REGISTER_BUS_WD       100
    `define WB_TO_CP0_REGISTER_BUS_WD 100
    `define EX_ADEL         4
    `define EX_ADES         5

    `define CR_COUNT        9
    `define CR_COMPARE      11
    `define CR_STATUS       12
    `define CR_CAUSE        13
    `define CR_EPC          14
`endif
