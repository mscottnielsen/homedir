" Vim syntax file
" Language:	PRM (GoldenGate Parameter file)
" Maintainer:	Michael S. Nielsen <mnielsen@goldengate.com>
" Last Change:	2006 May 20

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Use SQL syntax file as a starting point
if version < 600
   source <sfile>:p:h/sql.vim
else
   runtime! syntax/sql.vim
endif

" Groups which could have different formatting applied:
"   prmExtract 
"   prmExtractAndReplicat 
"   prmLogger 
"   prmMacro
"   prmManager 
"   prmManagerAndExtract 
"   prmManagerAndExtractAndReplicatAndLogger 
"   prmMap 
"   prmMappart 
"   prmMappartAndExtractAndReplicat 
"   prmReplicat 
"   prmTrail 
"
" Additional categories:
"   prmComment   (msn: added - have comments treated specially)
"   prmGGSCI     (msn: added - treat ggsci commands specially, eg., obey files)
"   prmDefGen    (msn: added - for defgen utility param file)


" ignore case - highlighting applies equally to upper/lower/mixed case.
syn case ignore

syn keyword prmExtract 	AllocFiles
syn keyword prmExtract 	AllowLargeTable
syn keyword prmExtract 	AltFileResolve
syn keyword prmExtract 	AuditRange
syn keyword prmExtract 	AuditRetrydelay
syn keyword prmExtract 	AuditRetrydelaycsecs
syn keyword prmExtract 	AudservCacheBlocks
syn keyword prmExtract 	AudservCpu
syn keyword prmExtract 	AudservCpus
syn keyword prmExtract 	AudservParam
syn keyword prmExtract 	AudservPrefix
syn keyword prmExtract 	AudservProcess
syn keyword prmExtract 	AudservProgram
syn keyword prmExtract 	Begin
syn keyword prmExtract 	CheckpointBytes
syn keyword prmExtract 	Checkpoints
syn keyword prmExtract 	DbOptions
syn keyword prmExtract 	Decrypt
syn keyword prmExtract 	DeleteLogRecs
syn keyword prmExtract 	DisplayTrailSwitch
syn keyword prmExtract 	DsOptions
syn keyword prmExtract 	DynamicPartitions
syn keyword prmExtract 	Encrypt
syn keyword prmExtract 	EncryptTrail
syn keyword prmExtract 	Error59rollover
syn keyword prmExtract 	EtoldFormat
syn keyword prmExtract 	ExtFile
syn keyword prmExtract 	Extract
syn keyword prmExtract 	ExtTrail
syn keyword prmExtract 	FastIO
syn keyword prmExtract 	FastPosition
syn keyword prmExtract 	FetchComps
syn keyword prmExtract 	FetchLastImage
syn keyword prmExtract 	FetchOptions
syn keyword prmExtract 	FileResolve
syn keyword prmExtract 	FillShortRecs
syn keyword prmExtract 	FilterView
syn keyword prmExtract 	FlushSecs
syn keyword prmExtract 	FormatAscii
syn keyword prmExtract 	FormatLoad
syn keyword prmExtract 	FormatLocal
syn keyword prmExtract 	FormatSql
syn keyword prmExtract 	FormatXml
syn keyword prmExtract 	IgnoreAuxTrails
syn keyword prmExtract 	InitAuxPosition
syn keyword prmExtract 	InitializeHeap
syn keyword prmExtract 	InputAscii
syn keyword prmExtract 	LimitRecs
syn keyword prmExtract 	MgrPort
syn keyword prmExtract 	NumExtracts
syn keyword prmExtract 	OmitAuditGapCheck
syn keyword prmExtract 	PassThru
syn keyword prmExtract 	PoolSize
syn keyword prmExtract 	PurgeRestore
syn keyword prmExtract 	ReadThruLocks
syn keyword prmExtract 	ReplaceBadChar
syn keyword prmExtract 	Restore
syn keyword prmExtract 	RmtBatch
syn keyword prmExtract 	RmtFile
syn keyword prmExtract 	RmtHost
syn keyword prmExtract 	RmtHostAlt
syn keyword prmExtract 	RmtPort
syn keyword prmExtract 	RmtTask
syn keyword prmExtract 	RmtTrail
syn keyword prmExtract 	RollOver
syn keyword prmExtract 	RecoveryOptions
syn keyword prmVariable 	OverwriteMode
syn keyword prmVariable 	AppendMode
syn keyword prmExtract 	SourceDB
syn keyword prmExtract 	SourceIsFile
syn keyword prmExtract 	SourceIsTable
syn keyword prmExtract 	SpecialRun
syn keyword prmExtract 	StatOptions
syn keyword prmExtract 	SupressAlterMessages
syn keyword prmExtract 	TargetDefs
syn keyword prmExtract 	TcpFlushBytes
syn keyword prmExtract 	TcpIpSwitchErrs
syn keyword prmExtract 	ThreadOptions
syn keyword prmExtract 	TlTrace
syn keyword prmExtract 	TmfRefreshInterval
syn keyword prmExtract 	TmfTrailTrace
syn keyword prmExtract 	TranLogOptions
syn keyword prmExtract 	TransBlockSize
syn keyword prmExtract 	TransMemory
syn keyword prmExtract 	UsePool
syn keyword prmExtract 	UseTransBlocks
syn keyword prmExtract 	Vam
syn keyword prmExtract 	VersionErr
syn keyword prmExtractAndReplicat 	AllowLargeFloat
syn keyword prmExtractAndReplicat 	AltInput
syn keyword prmExtractAndReplicat 	AsciiToEbcdic
syn keyword prmExtractAndReplicat 	BlobMemory
syn keyword prmExtractAndReplicat 	CheckParams
syn keyword prmExtractAndReplicat 	CheckPointSecs
syn keyword prmExtractAndReplicat 	CmdTrace
syn keyword prmExtractAndReplicat 	CobolUserExit
syn keyword prmExtractAndReplicat 	CUserExit
syn keyword prmExtractAndReplicat 	DecryptTrail
syn keyword prmExtractAndReplicat 	Dictionary
syn keyword prmExtractAndReplicat 	DiscardFile
syn keyword prmExtractAndReplicat 	DiscardRollover
syn keyword prmExtractAndReplicat 	DynamicResolution
syn keyword prmExtractAndReplicat 	End
syn keyword prmExtractAndReplicat 	EofDelay
syn keyword prmExtractAndReplicat 	EofDelayCsecs
syn keyword prmExtractAndReplicat 	ExpandDdl
syn keyword prmExtractAndReplicat 	FastReads
syn keyword prmExtractAndReplicat 	FunctionStackSize
syn keyword prmExtractAndReplicat 	GetEnv
syn keyword prmExtractAndReplicat 	GroupTransOps
syn keyword prmExtractAndReplicat 	Headers
syn keyword prmExtractAndReplicat 	Include
syn keyword prmExtractAndReplicat 	IncludeUpdateBefores
syn keyword prmExtractAndReplicat 	LagStats
syn keyword prmExtractAndReplicat 	List
syn keyword prmExtractAndReplicat 	Logon
syn keyword prmExtractAndReplicat 	MaxLongLen
syn keyword prmExtractAndReplicat 	MaxWildcardEntries
syn keyword prmExtractAndReplicat 	NetworkCheckPoints
syn keyword prmExtractAndReplicat 	NoTcpSourceTimer
syn keyword prmExtractAndReplicat 	NoTraceTable
syn keyword prmExtractAndReplicat 	NumFiles
syn keyword prmExtractAndReplicat 	Obey
syn keyword prmExtractAndReplicat 	PositionFirstRecord
syn keyword prmExtractAndReplicat 	PurgeOldExtracts
syn keyword prmExtractAndReplicat 	ReplaceBadChar
syn keyword prmExtractAndReplicat 	ReplaceBadNum
syn keyword prmExtractAndReplicat 	Report
syn keyword prmExtractAndReplicat 	ReportCount
syn keyword prmExtractAndReplicat 	ReportRollOver
syn keyword prmExtractAndReplicat 	RetryErr
syn keyword prmExtractAndReplicat 	SetEnv
syn keyword prmExtractAndReplicat 	ShortReadDelay
syn keyword prmExtractAndReplicat 	SourceDefs
syn keyword prmExtractAndReplicat 	SpName
syn keyword prmExtractAndReplicat 	SqlExec
syn keyword prmExtractAndReplicat 	StatOptions
syn keyword prmExtractAndReplicat 	SyskeyConvert
syn keyword prmExtractAndReplicat 	TcpSourceTimer
syn keyword prmExtractAndReplicat 	Trace
syn keyword prmExtractAndReplicat 	Trace2
syn keyword prmExtractAndReplicat 	TraceTable
syn keyword prmExtractAndReplicat 	UserId
syn keyword prmExtractAndReplicat 	Password
syn keyword prmExtractAndReplicat 	WildcardResolve
syn keyword prmExtractAndReplicat 	Y2kCenturyAdjustment
syn keyword prmGlobals	CheckPointTable
syn keyword prmLogger 	Active
syn keyword prmLogger 	CompressUpdates
syn keyword prmLogger 	Cpu
syn keyword prmLogger 	DebugOnStackCheck
syn keyword prmLogger 	ExcludeFile
syn keyword prmLogger 	File
syn keyword prmLogger 	FlushCsecs
syn keyword prmLogger 	FlushRecs
syn keyword prmLogger 	FlushSecs
syn keyword prmLogger 	ForceStopDelay
syn keyword prmLogger 	GetUnstructured
syn keyword prmLogger 	HeartBeat
syn keyword prmLogger 	Log
syn keyword prmLogger 	Logfileopens
syn keyword prmLogger 	LoggerFileNum
syn keyword prmLogger 	LoggerFlushCsecs
syn keyword prmLogger 	LoggerFlushRecs
syn keyword prmLogger 	LoggerFlushSecs
syn keyword prmLogger 	LoggerTimeoutSecs
syn keyword prmLogger 	NotStoppable
syn keyword prmLogger 	Priority
syn keyword prmLogger 	ReceiveQWarn
syn keyword prmLogger 	StopDelaySecs
syn keyword prmLogger 	Suspended
syn keyword prmLogger 	TraceAllOpens
syn keyword prmLogger 	TraceCloses
syn keyword prmLogger 	TraceOpens
syn keyword prmLogger 	TraceProcessIOs
syn keyword prmLogger 	TraceStats
syn keyword prmMacro   	Macro
syn keyword prmMacro   	MacroChar

syn keyword prmManager 	AccessRule
syn keyword prmManager 	AutoRestart
syn keyword prmManager 	AutoStart
syn keyword prmManager 	BackupCpu
syn keyword prmManager 	BootDelayMinutes
syn keyword prmManager 	CheckMinutes
syn keyword prmManager 	CleanupSaveCount
syn keyword prmManager 	DiskThreshold
syn keyword prmManager 	DownCritical
syn keyword prmManager 	DownReportHours
syn keyword prmManager 	DownReportMinutes
syn keyword prmManager 	DynamicPortList
syn keyword prmManager 	DynamicPortReassignDelay
syn keyword prmManager 	LagCriticalHours
syn keyword prmManager 	LagCriticalMinutes
syn keyword prmManager 	LagCriticalSeconds
syn keyword prmManager 	LagInfoHours
syn keyword prmManager 	LagInfoMinutes
syn keyword prmManager 	LagInfoSeconds
syn keyword prmManager 	LagReportHours
syn keyword prmManager 	LagReportMinutes
syn keyword prmManager 	LogfilesBehind
syn keyword prmManager 	LogfilesBehindInfo
syn keyword prmManager 	MaxAbendRestarts
syn keyword prmManager 	MaxTaclRestarts
syn keyword prmManager 	NoDiskThreshold
syn keyword prmManager 	NoThreshold
syn keyword prmManager 	Port
syn keyword prmManager 	PurgeOldExtracts
syn keyword prmManager 	PurgeOldHistory
syn keyword prmManager 	PurgeOldTasks
syn keyword prmManager 	RestartInterval
syn keyword prmManager 	SourceDB
syn keyword prmManager 	StartupValidationDelay
syn keyword prmManager 	StartupValidationDelayCsecs
syn keyword prmManager 	Threshold
syn keyword prmManager 	TmfDumpage
syn keyword prmManager 	TmfDumpTableEntries
syn keyword prmManager 	UpReportHours
syn keyword prmManager 	UpReportMinutes
syn keyword prmManager 	UserId
syn keyword prmManager 	Password
syn keyword prmManager 	UseThreads
syn keyword prmManager 	UseCheckpoints

syn keyword prmManagerAndExtract 	TcpIpProcessName

syn keyword prmMap 	CompressDeletes
syn keyword prmMap 	File
syn keyword prmMap 	FileExclude
syn keyword prmMap 	GetApplops
syn keyword prmMap 	GetReplicates
syn keyword prmMap 	Map
syn keyword prmMap 	Sequence
syn keyword prmMap 	SpacesToNull
syn keyword prmMap 	Table
syn keyword prmMap 	TableExclude
syn keyword prmMap 	Target
syn keyword prmMappart 	ColMap
syn keyword prmMappart 	ColMatch
syn keyword prmMappart 	CompressDeletes
syn keyword prmMappart 	CompressUpdates
syn keyword prmMappart 	GetAlters
syn keyword prmMappart 	GetAltKeys
syn keyword prmMappart 	GetApplops
syn keyword prmMappart 	GetAuxTrails
syn keyword prmMappart 	GetBulkIo
syn keyword prmMappart 	GetChangeLables
syn keyword prmMappart 	GetCloses
syn keyword prmMappart 	GetColumnChanges
syn keyword prmMappart 	GetCompressedUpdates
syn keyword prmMappart 	GetComps
syn keyword prmMappart 	GetControls
syn keyword prmMappart 	GetCreates
syn keyword prmMappart 	GetDefaults
syn keyword prmMappart 	GetDeletes
syn keyword prmMappart 	GetDrops
syn keyword prmMappart 	GetFileops
syn keyword prmMappart 	GetInserts
syn keyword prmMappart 	GetMarkers
syn keyword prmMappart 	GetNetChanges
syn keyword prmMappart 	GetNetUpdates
syn keyword prmMappart 	GetNetworkTrans
syn keyword prmMappart 	GetNewColumns
syn keyword prmMappart 	GetPurgedatas
syn keyword prmMappart 	GetPurges
syn keyword prmMappart 	GetRenames
syn keyword prmMappart 	GetReplicates
syn keyword prmMappart 	GetRollbacks
syn keyword prmMappart 	GetSetModes
syn keyword prmMappart 	GetTruncates
syn keyword prmMappart 	GetUpdateAfters
syn keyword prmMappart 	GetUpdateBefores
syn keyword prmMappart 	GetUpdates
syn keyword prmMappart 	InsertAllRecords
syn keyword prmMappart 	InsertDeletes
syn keyword prmMappart 	InsertMissingUpdates
syn keyword prmMappart 	InsertUpdates
syn keyword prmMappart 	TrimSpaces
syn keyword prmMappart 	NoCompressDeletes
syn keyword prmMappart 	NoCompressUpdates
syn keyword prmMappart 	UpdateDeletes
syn keyword prmMappart 	UpdateInserts
syn keyword prmMappart 	UseDefaults


syn keyword prmMappartAndExtractAndReplicat 	BinaryChars
syn keyword prmMappartAndExtractAndReplicat 	NoBinaryChars

syn keyword prmReplicat 	AllowDupTargetMap
syn keyword prmReplicat 	AllowLargeFloat
syn keyword prmReplicat 	AllowNoOpUpdates
syn keyword prmReplicat 	AssumeTargetDefs
syn keyword prmReplicat 	AuditReps
syn keyword prmReplicat 	AuditWarn
syn keyword prmReplicat 	BatchSql
syn keyword prmReplicat 	Begin
syn keyword prmReplicat 	BulkIoLen
syn keyword prmReplicat 	BulkIoLoad
syn keyword prmReplicat 	BulkLoad
syn keyword prmReplicat 	BulkLoadMessages
syn keyword prmReplicat 	CheckUniqueKey
syn keyword prmReplicat 	CheckUniqueKey2
syn keyword prmReplicat 	CompEnscribeMaps
syn keyword prmReplicat 	DbOptions
syn keyword prmReplicat 	DynSql
syn keyword prmReplicat 	EntrySeqUpdates
syn keyword prmReplicat 	EofDelayCsecs
syn keyword prmReplicat 	ExtFile
syn keyword prmReplicat 	ExtTrail
syn keyword prmReplicat 	FileOpsWarning
syn keyword prmReplicat 	FilterDups
syn keyword prmReplicat 	FixReversedInserts
syn keyword prmReplicat 	FixReversedUpdates
syn keyword prmReplicat 	FlushCheckPoint
syn keyword prmReplicat 	ForceUsesKey
syn keyword prmReplicat 	GenLoadFiles
syn keyword prmReplicat 	HandleCollisions
syn keyword prmReplicat 	MapExclude
syn keyword prmReplicat 	MaxDiscardRecs
syn keyword prmReplicat 	MaxEtCheckPointSecs
syn keyword prmReplicat 	MaxEtCheckPtSecs
syn keyword prmReplicat 	MaxSqlStatements
syn keyword prmReplicat 	MaxTransOps
syn keyword prmReplicat 	NoDynSql
syn keyword prmReplicat 	NoHeaders
syn keyword prmReplicat 	NoUseOciDbOps
syn keyword prmReplicat 	OpenTimeoutMinutes
syn keyword prmReplicat 	OpenWarnings
syn keyword prmReplicat 	OptimizeSqlUpdates
syn keyword prmReplicat 	OverrideDups
syn keyword prmReplicat 	PartMap
syn keyword prmReplicat 	PurgeDataAltFiles
syn keyword prmReplicat 	RepError
syn keyword prmReplicat 	ReplaceBadNum
syn keyword prmReplicat 	Replicat
syn keyword prmReplicat 	RepNewColumns
syn keyword prmReplicat 	RepSqlLog
syn keyword prmReplicat 	RestartCollisions
syn keyword prmReplicat 	RetryDelay
syn keyword prmReplicat 	ReverseWindowCsecs
syn keyword prmReplicat 	ReverseWindowSecs
syn keyword prmReplicat 	ShowSyntax
syn keyword prmReplicat 	SourceDefs
syn keyword prmReplicat 	SourceNodeNumber
syn keyword prmReplicat 	SpecialRun
syn keyword prmReplicat 	SqlDupErr
syn keyword prmReplicat 	SupressFileOpMessages
syn keyword prmReplicat 	SupressWildCardMessages
syn keyword prmReplicat 	TargetDB
syn keyword prmReplicat 	TdsPacketSize
syn keyword prmReplicat 	Timezone
syn keyword prmReplicat 	TmfExceptions
syn keyword prmReplicat 	Trace
syn keyword prmReplicat 	TraceApi
syn keyword prmReplicat 	TraceErDelay
syn keyword prmReplicat 	UseClusterKey
syn keyword prmReplicat 	UseDatePrefix
syn keyword prmReplicat 	UseTimePrefix
syn keyword prmReplicat 	UseTimestampPrefix
syn keyword prmReplicat 	WaitFileEvent
syn keyword prmReplicat 	WarnRate
syn keyword prmTrail 	Encryptval
syn keyword prmTrail 	Encriptval
syn keyword prmComment 	Comment
syn keyword prmGGSCI 	Add
syn keyword prmGGSCI 	Dblogin
syn keyword prmGGSCI 	Detail
syn keyword prmGGSCI 	Info
syn keyword prmGGSCI 	Megabytes
syn keyword prmGGSCI 	Now
syn keyword prmGGSCI 	Trandata
syn keyword prmGGSCI 	Tranlog
syn keyword prmGGSCI 	ExtTrailSource
syn keyword prmGGSCI 	VamTrailSource
syn keyword prmDefGen	Defsfile
syn keyword prmDefGen	Purge
syn keyword prmDefGen	Append


" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_prm_syntax_inits")
  if version < 508
    let did_prm_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " using for a white background for recorded demo's
  " hi keyword gui=bold ctermfg=black cterm=underline
  hi def keywordEm	term=bold,underline cterm=bold,underline gui=bold,underline

  HiLink prmkeywordEm	keywordEm
  HiLink prmMacro	Macro
  HiLink prmVariable	Identifier

  HiLink prmVariable	Identifier

  HiLink prmExtract   	keywordEm
  HiLink prmExtractAndReplicat 	keywordEm
  HiLink prmDefGen  	keywordEm
  HiLink prmLogger  	keywordEm
  HiLink prmManager 	keywordEm
  HiLink prmManagerAndExtract  	keywordEm
  HiLink prmManagerAndExtractAndReplicatAndLogger 	keywordEm
  HiLink prmMap 	keywordEm
  HiLink prmMappart  	keywordEm
  HiLink prmMappartAndExtractAndReplicat 	keywordEm
  HiLink prmReplicat 	keywordEm
  HiLink prmTrail   	keywordEm
  HiLink prmComment 	Comment
  HiLink prmGGSCI  	Special
  " no GLOBALS file keywords by default, since no file extension
  HiLink prmGlobals 	keywordEm

  delcommand HiLink
endif

let b:current_syntax = "prm"

" vim: ts=8
