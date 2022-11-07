#
# Topology for Renoir with I2S SP and DMIC.
#

# Include topology builder
include(`utils.m4')
include(`dai.m4')
include(`pipeline.m4')
include(`acp-hs.m4')
include(`acp-dmic.m4')
include(`m4/debug.m4')
include(`muxdemux.m4')
include(`bytecontrol.m4')

# Include TLV library
include(`common/tlv.m4')
# Include Token library
include(`sof/tokens.m4')

# Include ACP DSP configuration
include(`platform/amd/acp.m4')


DEBUG_START

define(PIPE_NAME, pipe-acp-mux)

#
# Define the pipelines
#
# PCM0 ----> volume ---------------+
#                                  |--low latency mixer ----> volume ---->  ACPSP_play
# PCM1 -----> volume ----->     ---+
#
# PCM0 <---- Volume <---- ACPSP_Capture
#

#/**********************************************************************************/
mux pipe1 and pipe3
define(matrix1, `ROUTE_MATRIX(1,
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,1 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,1 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,1 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,1)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)')')

define(matrix2, `ROUTE_MATRIX(3,
			     `BITS_TO_BYTE(0, 0, 1 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,1 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(1, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 1, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)')')

dnl name, num_streams, route_matrix list
MUXDEMUX_CONFIG(demux_priv_1, 2, LIST_NONEWLINE(`', `matrix1,', `matrix2'))

#PLAY BACK and CAPTURE
# Low Latency playback pipeline 1 on PCM 0 using max 2 channels of s16le.
# 1000us deadline on core 0 with priority 1
PIPELINE_PCM_ADD(sof/pipe-low-latency-playback_mux_tdm4ch.m4,
        1, 0, 2, s16le,
        2000, 0, 0,
        48000, 48000, 48000)

# DAI configuration
# ACPSP port 0 is our only pipeline DAI
# playback DAI is ACPSP using 2 periods
# Buffers use s16le format, 1000us deadline with priority 0 on core 0
DAI_ADD(sof/pipe-dai-playback.m4,
	1, ACPHS, 0, acp-headset-codec,
	PIPELINE_SOURCE_1, 2, s16le,
	2000, 0, 0, SCHEDULE_TIME_DOMAIN_DMA)

#/**********************************************************************************/
DAI_ADD(sof/pipe-dai-playback.m4,
	9, ACPHS_VIRTUAL, 1, acp-amp-codec,
	PIPELINE_SOURCE_1, 4, s16le,
	2000, 0, 0, SCHEDULE_TIME_DOMAIN_DMA)

DAI_CONFIG(ACPHS_VIRTUAL, 1, 1, acp-amp-codec,
	   ACPHS_VIRTUAL_CONFIG(I2S, ACP_CLOCK(mclk, 49152000, codec_mclk_in),
                ACP_CLOCK(bclk, 3072000, codec_slave),
                ACP_CLOCK(fsync, 48000, codec_slave),
                ACP_TDM(8, 32, 3, 3),ACPHS_VIRTUAL_CONFIG_DATA(ACPHS_VIRTUAL, 1, 48000, 8, 1)))
PCM_PLAYBACK_ADD(Low Latency, 0, PIPELINE_PCM_9)
#/**********************************************************************************/


# PCM Media Playback pipeline 3 on PCM 1 using max 2 channels of s16le.
# 2000us deadline with priority 0 on core 0
PIPELINE_PCM_ADD(sof/pipe-pcm-mux.m4,
	3, 1, 2, s16le,
	2000, 0, 0,
	48000, 48000, 48000,
        SCHEDULE_TIME_DOMAIN_DMA,
	PIPELINE_PLAYBACK_SCHED_COMP_1)

# Connect pipelines together
SectionGraph."PIPE_NAME" {
	index "0"
	lines [
		# media 0
		dapm(PIPELINE_DEMUX_1, PIPELINE_SOURCE_3)
	]
}
#/**********************************************************************************/

#/**********************************************************************************/
define(matrix3, `ROUTE_MATRIX(2,
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,1 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,1)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,0)')')

dnl name, num_streams, route_matrix list
MUXDEMUX_CONFIG(demux_priv_2, 1, LIST_NONEWLINE(`', `matrix3'))
# Low Latency capture pipeline 2 on PCM 0 using max 2 channels of s16le.
# 2000us deadline with priority 0 on core 0
#PIPELINE_PCM_ADD(sof/pipe-passthrough-capture.m4,
PIPELINE_PCM_ADD(sof/pipe-low-latency-capture-demux.m4,
        2, 0, 8, s16le,
        2000, 0, 0,
        48000, 48000, 48000)

# Capture DAI is ACPSP using 2 periods
# Buffers use s16le format, 1000us deadline with priority 0 on core 0
DAI_ADD(sof/pipe-dai-capture.m4,
	2, ACPHS, 0, acp-headset-codec,
	PIPELINE_SINK_2, 2, s16le,
	2000, 0, 0, SCHEDULE_TIME_DOMAIN_DMA)

# BE configurations -
DAI_CONFIG(ACPHS, 0, 0, acp-headset-codec,
	ACPHS_CONFIG(I2S, ACP_CLOCK(mclk, 49152000, codec_mclk_in),
	ACP_CLOCK(bclk, 3072000, codec_slave),
	ACP_CLOCK(fsync, 48000, codec_slave),
	ACP_TDM(8, 32, 3, 3),ACPHS_CONFIG_DATA(ACPHS, 0, 48000, 8, 1)))

# PCM Low Latency
PCM_DUPLEX_ADD(Low Latency, 0, PIPELINE_PCM_1, PIPELINE_PCM_2)
#/**********************************************************************************/

#/**********************************************************************************/
#DMIC

# Capture pipeline 3-->5 on PCM 1-->6 using max 2 channels of s32le.
PIPELINE_PCM_ADD(sof/pipe-passthrough-capture.m4,
        5, 6, 4, s32le,
        2000, 0, 0,
        48000, 48000, 48000)


DAI_ADD(sof/pipe-dai-capture.m4, 5, ACPDMIC, 0, acp-dmic-codec,
PIPELINE_SINK_5, 2, s32le, 2000, 0, 0, SCHEDULE_TIME_DOMAIN_DMA)

dnl DAI_CONFIG(type, dai_index, link_id, name, acpdmic_config)
DAI_CONFIG(ACPDMIC, 5, 2, acp-dmic-codec,
	   ACPDMIC_CONFIG(ACPDMIC_CONFIG_DATA(ACPDMIC, 5, 48000, 4)))

# PCM id 1
PCM_CAPTURE_ADD(DMIC, 6, PIPELINE_PCM_5)
#/**********************************************************************************/

VIRTUAL_WIDGET(ACPHS0 OUT, output, 0)
VIRTUAL_WIDGET(ACPHS0 IN, input, 1)
VIRTUAL_WIDGET(DMIC0 Capture, input, 2)
#VIRTUAL_WIDGET(ACPHS_VIRTUAL OUT, output, 3)
#VIRTUAL_WIDGET(ACPHS_VIRTUAL IN, input, 4)


DEBUG_END
