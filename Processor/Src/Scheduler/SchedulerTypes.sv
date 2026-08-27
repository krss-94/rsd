// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.


//
// --- Types related to an issue queue.
//

package SchedulerTypes;

import MicroArchConf::*;
import BasicTypes::*;
import CacheSystemTypes::*;
import MemoryMapTypes::*;
import MicroOpTypes::*;
import OpFormatTypes::*;
import BypassTypes::*;
import RenameLogicTypes::*;
import LoadStoreUnitTypes::*;
import FetchUnitTypes::*;
import ActiveListIndexTypes::*;

// Issue queue
localparam ISSUE_QUEUE_ENTRY_NUM = CONF_ISSUE_QUEUE_ENTRY_NUM;
localparam ISSUE_QUEUE_ENTRY_NUM_BIT_WIDTH = $clog2(ISSUE_QUEUE_ENTRY_NUM);

typedef logic [ISSUE_QUEUE_ENTRY_NUM_BIT_WIDTH-1:0] IssueQueueIndexPath;
typedef logic [ISSUE_QUEUE_ENTRY_NUM_BIT_WIDTH:0] IssueQueueCountPath;

typedef logic [ISSUE_QUEUE_ENTRY_NUM-1:0] IssueQueueOneHotPath;

localparam ISSUE_QUEUE_SRC_REG_NUM = MICRO_OP_SOURCE_REG_NUM;

localparam ISSUE_QUEUE_INT_LATENCY     = 1;
//localparam ISSUE_QUEUE_COMPLEX_LATENCY = COMPLEX_EXEC_STAGE_DEPTH;
localparam ISSUE_QUEUE_COMPLEX_LATENCY = COMPLEX_EXEC_STAGE_DEPTH + 2;
localparam ISSUE_QUEUE_MEM_LATENCY     = 3;
localparam ISSUE_QUEUE_FP_LATENCY      = FP_EXEC_STAGE_DEPTH + 2;

localparam WAKEUP_WIDTH = INT_ISSUE_WIDTH + COMPLEX_ISSUE_WIDTH + LOAD_ISSUE_WIDTH + FP_ISSUE_WIDTH;    // Stores do not wakeup consumers.

// --- Issue queue flush count
// - ä¾‹å¤–ç™ºç”Ÿæ™‚ã«ã€ç™ºè¡Œã‚­ãƒ¥ãƒ¼ã¯ä¾‹å¤–å‘½ä»¤ã‚ˆã‚Šå¾Œæ–¹ã®å‘½ä»¤ãŒé¸æŠžçš„ã«ãƒ•ãƒ©ãƒƒã‚·ãƒ¥ã•ã‚Œã‚‹ã€‚
//   ãã®éš›ã€ãƒ•ãƒªãƒ¼ãƒªã‚¹ãƒˆã¸ã®ã‚¤ãƒ³ãƒ‡ãƒƒã‚¯ã‚¹ã®è¿”å´ã¯å°‚ç”¨ã®ãƒãƒ¼ãƒˆã‚’ä»‹ã—ã¦è¤‡æ•°ã‚µã‚¤ã‚¯ãƒ«ã§è¡Œã‚ã‚Œã‚‹ã€‚
//   ISSUE_QUEUE_RESET_CYCLE ã¯ãã®ã‚µã‚¤ã‚¯ãƒ«æ•°ã‚’è¡¨ã™ã€‚
localparam ISSUE_QUEUE_RETURN_INDEX_WIDTH = 2;
localparam ISSUE_QUEUE_RETURN_INDEX_CYCLE
    = (ISSUE_QUEUE_ENTRY_NUM-1) / ISSUE_QUEUE_RETURN_INDEX_WIDTH + 1; // å‰²ã‚Šç®—ã—ã¦åˆ‡ã‚Šä¸Šã’
localparam ISSUE_QUEUE_RETURN_INDEX_CYCLE_BIT_SIZE
    = $clog2( ISSUE_QUEUE_RETURN_INDEX_CYCLE );

// --- Issue queue reset count
localparam ISSUE_QUEUE_RESET_CYCLE
    = (ISSUE_QUEUE_ENTRY_NUM-1) / (ISSUE_WIDTH+ISSUE_QUEUE_RETURN_INDEX_WIDTH) + 1; // å‰²ã‚Šç®—ã—ã¦åˆ‡ã‚Šä¸Šã’
localparam ISSUE_QUEUE_RESET_CYCLE_BIT_SIZE
    = $clog2( ISSUE_QUEUE_RESET_CYCLE );


// Information about the execution of an op.
typedef enum logic [3:0] // ExecutionState
{
    EXEC_STATE_NOT_FINISHED     = 4'b0000,
    EXEC_STATE_SUCCESS          = 4'b0001, // Execution is successfully finished.
    
    EXEC_STATE_REFETCH_THIS     = 4'b0010, // Execution is failed.
                                           // It must be refetch from this op. 
    EXEC_STATE_REFETCH_NEXT     = 4'b0011, // Execution is successfully finished,
                                           // but it must be refetch from next op.
    EXEC_STATE_TRAP_ECALL       = 4'b0100, // Execution causes a trap (ECALL)
    EXEC_STATE_TRAP_EBREAK      = 4'b0101, // Execution causes a trap (EBREAK)
    EXEC_STATE_TRAP_MRET        = 4'b0110,  // Execution causes a MRET

    EXEC_STATE_FAULT_LOAD_MISALIGNED  = 4'b1000,  // Misaligned load is executed
    EXEC_STATE_FAULT_LOAD_VIOLATION   = 4'b1001,  // Load access violation
    EXEC_STATE_FAULT_STORE_MISALIGNED = 4'b1010,  // Misaligned store is executed
    EXEC_STATE_FAULT_STORE_VIOLATION  = 4'b1011,  // Store access violation
    EXEC_STATE_STORE_LOAD_FORWARDING_MISS  = 4'b1111,  // Store load forwarding miss

    EXEC_STATE_FAULT_INSN_ILLEGAL     = 4'b1100,  // Illegal instruction
    EXEC_STATE_FAULT_INSN_VIOLATION   = 4'b1101,  // Illegal instruction
    EXEC_STATE_FAULT_INSN_MISALIGNED  = 4'b1110   // Misaligned instruction address
} ExecutionState;
localparam EXEC_STATE_BIT_WIDTH = $bits(ExecutionState);

typedef struct packed // ActiveListEntry
{
    `ifndef RSD_DISABLE_DEBUG_REGISTER // Debug info
        OpId      opId;
    `endif

    PC_Path pc;
    
    LRegNumPath logDstRegNum;
    logic writeReg;
    
    logic isLoad;
    logic isStore;
    logic isBranch; // TRUE if the op is BR or RIJ
    logic isEnv;    // TRUE if the op is ECALL/EBREAK
    
    logic last;         // TRUE if this micro-op is the last micro-op in an instruction
    logic undefined;
    
    // For releasing a register to a free list on recovery.
    PRegNumPath  phyDstRegNum;

    // For releasing a register to a free list on commitment.
    // and recovering a RMT.
    PRegNumPath  phyPrevDstRegNum;

    IssueQueueIndexPath prevDependIssueQueuePtr;
    
} ActiveListEntry;


typedef struct packed // ActiveListWriteData
{
    ActiveListIndexPath ptr;
    LoadQueueIndexPath loadQueuePtr;
    StoreQueueIndexPath storeQueuePtr;
    ExecutionState      state;
    PC_Path             pc;
    AddrPath            dataAddr;
    logic               isBranch;
    logic               isStore;
} ActiveListWriteData;


// Convert a pointer of an active list to an "age."
// An "age" can be directly compared with a comparator.
function automatic ActiveListCountPath ActiveListPtrToAge(ActiveListIndexPath ptr, ActiveListIndexPath head);
    ActiveListCountPath age;
    age = ptr;
    if (ptr < head)
        return age + ACTIVE_LIST_ENTRY_NUM; // Wrap around.
    else
        return age;
endfunction


//
// --- OpInfo of Integer Pipeline
//

// IntOpSubInfo ã¨ BrOpSubInfo ã®ãƒ“ãƒƒãƒˆå¹…ã‚’åˆã‚ã›ã‚‹ãŸã‚ã®ã€€padding ã®è¨ˆç®—ã‚’ã™ã‚‹
localparam INT_SUB_INFO_BIT_WIDTH = 
    $bits(OpOperandType) * 2 + $bits(IntALU_Code) + $bits(ShiftOperandType) + $bits(ShifterPath);
localparam BR_SUB_INFO_BIT_WIDTH =
    $bits(OpOperandType) * 2 + $bits(BranchPred) + $bits(BranchDisplacement);
    
localparam INT_SUB_INFO_PADDING_BIT_WIDTH = 
    BR_SUB_INFO_BIT_WIDTH - INT_SUB_INFO_BIT_WIDTH;

//
typedef struct packed // IntOpInfo
{

    // è«–ç†ãƒ¬ã‚¸ã‚¹ã‚¿ã‚’èª­ã‚€ã‹ã©ã†ã‹
    OpOperandType operandTypeA;
    OpOperandType operandTypeB;

    IntALU_Code aluCode;

    // å³å€¤
    ShiftOperandType shiftType;
    ShifterPath      shiftIn;

    // BrOpSubInfo ã¨ãƒ“ãƒƒãƒˆå¹…ã‚’åˆã‚ã›ã‚‹ãŸã‚ã® padding
    logic [INT_SUB_INFO_PADDING_BIT_WIDTH-1:0] padding;
} IntOpSubInfo;

//
typedef struct packed // BrOpInfo
{
    // è«–ç†ãƒ¬ã‚¸ã‚¹ã‚¿ã‚’èª­ã‚€ã‹ã©ã†ã‹
    OpOperandType operandTypeA;
    OpOperandType operandTypeB;

    BranchPred bPred;
    BranchDisplacement brDisp;        // åˆ†å²ã‚¿ãƒ¼ã‚²ãƒƒãƒˆ
} BrOpSubInfo;

typedef union packed    // IntOpInfo
{
    IntOpSubInfo intSubInfo;
    BrOpSubInfo  brSubInfo;
} IntOpInfo;

typedef struct packed // IntIssueQueueEntry
{
`ifndef RSD_DISABLE_DEBUG_REGISTER // Debug info
    OpId      opId;
`endif

    // Decoded op information
    IntOpInfo intOpInfo;

    IntMicroOpSubType opType;
    CondCode cond;
    ActiveListIndexPath activeListPtr;
    LoadQueueIndexPath loadQueueRecoveryPtr;    //for recovery
    StoreQueueIndexPath storeQueueRecoveryPtr;    //for recovery
    OpSrc opSrc;
    OpDst opDst;
    PC_Path pc;
} IntIssueQueueEntry;


//
// --- OpInfo of Complex Integer Pipeline
//

// 1+2=3
typedef struct packed // MulOpInfo
{
    logic mulGetUpper; // ä¹—ç®—ã§33-64bitç›®ã‚’çµæžœã¨ã™ã‚‹ã‹å¦ã‹
    IntMUL_Code mulCode;
} MulOpSubInfo;

// 1+2=3
typedef struct packed // DivOpInfo
{
    logic padding;
    IntDIV_Code divCode;
} DivOpSubInfo;

typedef union packed    // ComplexOpInfo
{
    MulOpSubInfo  mulSubInfo;
    DivOpSubInfo  divSubInfo;
} ComplexOpInfo;

typedef struct packed // ComplexIssueQueueEntry
{
`ifndef RSD_DISABLE_DEBUG_REGISTER // Debug info
    OpId      opId;
`endif

    // Decoded op information
    ComplexOpInfo complexOpInfo;
    ComplexMicroOpSubType opType;

    ActiveListIndexPath activeListPtr;
    LoadQueueIndexPath loadQueueRecoveryPtr;    //for recovery
    StoreQueueIndexPath storeQueueRecoveryPtr;    //for recovery
    OpSrc opSrc;
    OpDst opDst;
    PC_Path pc;
} ComplexIssueQueueEntry;

typedef struct packed // MemOpInfo
{
    MemMicroOpSubType opType;

    // æ¡ä»¶ã‚³ãƒ¼ãƒ‰
    CondCode cond;

    // è«–ç†ãƒ¬ã‚¸ã‚¹ã‚¿ã‚’èª­ã‚€ã‹ã©ã†ã‹
    OpOperandType operandTypeA;
    OpOperandType operandTypeB;

    // ã‚¢ãƒ‰ãƒ¬ãƒƒã‚·ãƒ³ã‚°
    AddrOperandImm addrIn;
    logic isAddAddr;    // ã‚ªãƒ•ã‚»ãƒƒãƒˆåŠ ç®—
    logic isRegAddr;    // ãƒ¬ã‚¸ã‚¹ã‚¿ã‚¢ãƒ‰ãƒ¬ãƒƒã‚·ãƒ³ã‚°
    MemAccessMode memAccessMode; // signed/unsigned and access size

    // CSR
    CSR_CtrlPath csrCtrl;
    ENV_Code envCode;

    // FENCE.I
    logic isFenceI;

    // Complex
`ifdef RSD_MARCH_UNIFIED_MULDIV_MEM_PIPE
    MulOpSubInfo mulSubInfo;
    DivOpSubInfo divSubInfo;
`endif

} MemOpInfo;

typedef struct packed // MemIssueQueueEntry
{
`ifndef RSD_DISABLE_DEBUG_REGISTER // Debug info
    OpId      opId;
`endif

    // Decoded op information
    MemOpInfo memOpInfo;    

    // Pointer of LSQ
    LoadQueueIndexPath loadQueuePtr;
    StoreQueueIndexPath storeQueuePtr;

    // Whether this load has allocated MSHR or not
    logic hasAllocatedMSHR;
    MSHR_IndexPath mshrID;

    ActiveListIndexPath activeListPtr;
    LoadQueueIndexPath loadQueueRecoveryPtr;    //for recovery
    StoreQueueIndexPath storeQueueRecoveryPtr;    //for recovery
    OpSrc opSrc;
    OpDst opDst;
    PC_Path pc;
} MemIssueQueueEntry;

typedef struct packed // FPOpInfo
{
    FPMicroOpSubType opType;
    FPU_Code fpuCode;
    Rounding_Mode rm;

    // è«–ç†ãƒ¬ã‚¸ã‚¹ã‚¿ã‚’èª­ã‚€ã‹ã©ã†ã‹
    OpOperandType operandTypeA;
    OpOperandType operandTypeB;
    OpOperandType operandTypeC;
} FPOpInfo;

typedef struct packed // FPIssueQueueEntry
{
`ifndef RSD_DISABLE_DEBUG_REGISTER // Debug info
    OpId      opId;
`endif

    FPOpInfo fpOpInfo;

    ActiveListIndexPath activeListPtr;
    LoadQueueIndexPath loadQueueRecoveryPtr;    //for recovery
    StoreQueueIndexPath storeQueueRecoveryPtr;    //for recovery
    OpSrc opSrc;
    OpDst opDst;
    PC_Path pc;
} FPIssueQueueEntry;

//
// Entry of Scheduler
//

typedef struct packed // SchedulerEntry
{
    MicroOpType opType;
    MicroOpSubType opSubType;

    logic srcRegValidA;
    logic srcRegValidB;
`ifdef RSD_MARCH_FP_PIPE
    logic srcRegValidC;
`endif
    OpSrc opSrc;
    OpDst opDst;

    // Pointer to producers in an issue queue.
    IssueQueueIndexPath srcPtrRegA;
    IssueQueueIndexPath srcPtrRegB;
`ifdef RSD_MARCH_FP_PIPE
    IssueQueueIndexPath srcPtrRegC;
`endif
} SchedulerEntry;


//
// A tag for a source CAM and a ready bit table.
// These tags are used for a ready bit table, thus they are necessary in
// matrix based implementation.
//

// For a physic's register.
typedef struct packed // SchedulerRegTag
{
    PRegNumPath num;
    logic valid;
} SchedulerRegTag;

//
// A pointer for a producer matrix.
//

// For a physical register.
typedef struct packed // SchedulerRegPtr
{
    IssueQueueIndexPath ptr;
    logic valid;
} SchedulerRegPtr;

//
// For the destination operand of an op.
//
typedef struct packed // SchedulerDstTag
{
    SchedulerRegTag  regTag;
} SchedulerDstTag;

// For the source operands of an op.
typedef struct packed // SchedulerSrcTag
{
    SchedulerRegTag  [ISSUE_QUEUE_SRC_REG_NUM-1:0] regTag;
    SchedulerRegPtr  [ISSUE_QUEUE_SRC_REG_NUM-1:0] regPtr;
} SchedulerSrcTag;

// Replay queue
localparam REPLAY_QUEUE_ENTRY_NUM = CONF_REPLAY_QUEUE_ENTRY_NUM;
localparam REPLAY_QUEUE_ENTRY_NUM_BIT_WIDTH = $clog2(REPLAY_QUEUE_ENTRY_NUM);
typedef logic [REPLAY_QUEUE_ENTRY_NUM_BIT_WIDTH-1 : 0] ReplayQueueIndexPath;
typedef logic [REPLAY_QUEUE_ENTRY_NUM_BIT_WIDTH : 0] ReplayQueueCountPath;

// Memory Dependent Predictor
localparam MDT_ENTRY_NUM = CONF_MDT_ENTRY_NUM;
localparam MDT_COUNTER_BIT_WIDTH = CONF_MDT_COUNTER_BIT_WIDTH;
localparam MDT_ENTRY_NUM_BIT_WIDTH = $clog2(MDT_ENTRY_NUM);
typedef logic [MDT_ENTRY_NUM_BIT_WIDTH-1:0] MDT_IndexPath;

typedef struct packed // struct MDT_Entry
{
    logic [MDT_COUNTER_BIT_WIDTH-1:0] counter; // V1-W2: widened from 1 bit (V0) to 2 bits
} MDT_Entry;

function automatic MDT_IndexPath ToMDT_Index(PC_Path addr);
    return
        addr[
            MDT_ENTRY_NUM_BIT_WIDTH + INSN_ADDR_BIT_WIDTH - 1: 
            INSN_ADDR_BIT_WIDTH
        ];
endfunction

endpackage : SchedulerTypes

