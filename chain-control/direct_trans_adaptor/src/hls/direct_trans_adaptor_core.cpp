/*************************************************
* Copyright 2024 NTT Corporation, FUJITSU LIMITED
* Licensed under the Apache License, Version 2.0, see LICENSE for details.
* SPDX-License-Identifier: Apache-2.0
*************************************************/

#include "direct_trans_adaptor.hpp"

void ingr_ctrl_req(hls::stream<sessionReq> &s_axis_ingr_rx_req,
                   hls::stream<sessionReq> &m_axis_ingr_tx_req,
                   hls::stream<sessionReq> &direct_req,
                   hls::stream<sessionReq> &ingr_ctrl_queue,
                   faultProtocol &ingr_snd_insert_protocol_fault)
{
#pragma HLS pipeline II = 1

  if (!s_axis_ingr_rx_req.empty())
  {
    sessionReq req_read;
    s_axis_ingr_rx_req.read_nb(req_read);

    if (req_read.direct == 0)
    {
      // insert fault
      if (ingr_snd_insert_protocol_fault.burst_length_nz)
      {
        req_read.burst_length = 0;
      }
      else if (ingr_snd_insert_protocol_fault.max_burst_length)
      {
        req_read.burst_length = MAX_BURST_LENGTH + 1;
      }

      // function
      m_axis_ingr_tx_req.write(req_read);
    }
    else
    {
      // direct transfer
      direct_req.write(req_read);
    }

    ingr_ctrl_queue.write(req_read);
  }
}

void ingr_ctrl_resp(hls::stream<sessionReq> &s_axis_ingr_tx_resp,
                    hls::stream<sessionReq> &direct_resp,
                    hls::stream<sessionReq> &ingr_ctrl_queue,
                    hls::stream<sessionReq> &m_axis_ingr_rx_resp,
                    hls::stream<sessionReq> &ingr_trans_queue,
                    channelFrameCount &stat_ingr_rcv_frame,
                    channelFrameCount &stat_ingr_snd_frame,
                    faultProtocol &ingr_rcv_insert_protocol_fault)
{
#pragma HLS pipeline II = 1

  static sessionReq direction;
  static bool direction_vld = false;

  if (direction_vld &&
      (direction.direct == 0) &&
      !s_axis_ingr_tx_resp.empty())
  {
    // select function
    sessionReq read_resp;
    s_axis_ingr_tx_resp.read_nb(read_resp);

    // insert fault
    if (ingr_rcv_insert_protocol_fault.channel_eq)
    {
      read_resp.channel = ~read_resp.channel;
    }
    if (ingr_rcv_insert_protocol_fault.burst_length_le)
    {
      read_resp.burst_length = MAX_BURST_LENGTH;
    }
    if (ingr_rcv_insert_protocol_fault.sof_eq)
    {
      read_resp.sof = ~read_resp.sof;
    }
    if (ingr_rcv_insert_protocol_fault.eof_eq)
    {
      read_resp.eof = ~read_resp.eof;
    }

    m_axis_ingr_rx_resp.write(read_resp);
    read_resp.direct = direction.direct; // propagate direction
    ingr_trans_queue.write(read_resp);

    if ((direction.sof == 1) && (read_resp.burst_length > 0))
    {
      stat_ingr_rcv_frame = channelFrameCount(0, read_resp.channel);
      stat_ingr_snd_frame = channelFrameCount(0, read_resp.channel);
    }

    direction_vld = false;
  }
  else if (direction_vld &&
           (direction.direct == 1) &&
           !direct_resp.empty())
  {
    // select direct transfer
    sessionReq read_resp;
    direct_resp.read_nb(read_resp);

    // insert fault
    if (ingr_rcv_insert_protocol_fault.channel_eq)
    {
      read_resp.channel = ~read_resp.channel;
    }
    if (ingr_rcv_insert_protocol_fault.burst_length_le)
    {
      read_resp.burst_length = MAX_BURST_LENGTH;
    }
    if (ingr_rcv_insert_protocol_fault.sof_eq)
    {
      read_resp.sof = ~read_resp.sof;
    }
    if (ingr_rcv_insert_protocol_fault.eof_eq)
    {
      read_resp.eof = ~read_resp.eof;
    }

    m_axis_ingr_rx_resp.write(read_resp);
    read_resp.direct = direction.direct; // propagate direction
    ingr_trans_queue.write(read_resp);

    if ((direction.sof == 1) && (read_resp.burst_length > 0))
    {
      stat_ingr_rcv_frame = channelFrameCount(0, read_resp.channel);
    }

    direction_vld = false;
  }
  else if (!direction_vld &&
           !ingr_ctrl_queue.empty())
  {
    // dequeue next
    ingr_ctrl_queue.read_nb(direction);
    direction_vld = true;
  }
}

void ingr_trans(hls::stream<sessionReq> &ingr_trans_queue,
                hls::stream<session_data_t> &s_axis_ingr_rx_data,
                hls::stream<session_data_t> &m_axis_ingr_tx_data,
                hls::stream<session_data_t> &direct_data,
                channelCycleDataCount &stat_ingr_rcv_data,
                channelCycleDataCount &stat_ingr_snd_data,
                faultProtocol &ingr_snd_insert_protocol_fault)
{
#pragma HLS pipeline II = 1

  static uint32_t count_data = 0;
  static bool trans_read_vld = false;
  static sessionReq trans_read;

  // Count data
  if (!s_axis_ingr_rx_data.empty() &&
      trans_read_vld &&
      (trans_read.direct == 0))
  {
    // forward function data
    session_data_t trans_data;
    s_axis_ingr_rx_data.read_nb(trans_data);
    m_axis_ingr_tx_data.write(trans_data);

    if (count_data > 1)
    {
      stat_ingr_rcv_data = channelCycleDataCount(0, trans_read.channel, TRANS_DATA_WIDTH_BYTES);
      stat_ingr_snd_data = channelCycleDataCount(0, trans_read.channel, TRANS_DATA_WIDTH_BYTES);

      // decrement
      trans_read_vld = true;
      count_data--;
    }
    else
    {
      uint8_t bytenum = (trans_read.burst_length % TRANS_DATA_WIDTH_BYTES == 0) ? TRANS_DATA_WIDTH_BYTES : trans_read.burst_length % TRANS_DATA_WIDTH_BYTES;

      stat_ingr_rcv_data = channelCycleDataCount(0, trans_read.channel, bytenum);
      stat_ingr_snd_data = channelCycleDataCount(0, trans_read.channel, bytenum);

      // current transaction data end
      trans_read_vld = false;
      count_data = 0;
    }
  }
  else if (!s_axis_ingr_rx_data.empty() &&
           trans_read_vld &&
           (trans_read.direct == 1))
  {
    // forward direct data
    session_data_t trans_data;
    s_axis_ingr_rx_data.read_nb(trans_data);
    direct_data.write(trans_data);

    if (count_data > 1)
    {
      stat_ingr_rcv_data = channelCycleDataCount(0, trans_read.channel, TRANS_DATA_WIDTH_BYTES);

      // decrement
      trans_read_vld = true;
      count_data--;
    }
    else
    {
      uint8_t bytenum = (trans_read.burst_length % TRANS_DATA_WIDTH_BYTES == 0) ? TRANS_DATA_WIDTH_BYTES : trans_read.burst_length % TRANS_DATA_WIDTH_BYTES;

      stat_ingr_rcv_data = channelCycleDataCount(0, trans_read.channel, bytenum);

      // current transaction data end
      trans_read_vld = false;
      count_data = 0;
    }
  }
  else if (!trans_read_vld &&
           !ingr_trans_queue.empty())
  {
    ingr_trans_queue.read_nb(trans_read);

    if (trans_read.burst_length > 0)
    {
      // current transaction set
      trans_read_vld = true;
      count_data = CDIV(trans_read.burst_length, TRANS_DATA_WIDTH_BYTES);
    }
    else
    {
      // current transaction data is empty
      trans_read_vld = false;
      count_data = 0;
    }
  }
}

void egr_ctrl_req(hls::stream<sessionReq> &s_axis_egr_rx_req,
                  hls::stream<sessionReq> &direct_req,
                  hls::stream<sessionReq> &egr_ctrl_queue,
                  hls::stream<sessionReq> &m_axis_egr_tx_req,
                  faultProtocol &egr_snd_insert_protocol_fault)
{
#pragma HLS pipeline II = 1

  static bool direct_priority = false;

  if (!s_axis_egr_rx_req.empty() &&
      !direct_req.empty())
  {
    // select
    if (!direct_priority)
    {
      sessionReq req_read;
      s_axis_egr_rx_req.read_nb(req_read);

      // insert fault
      if (egr_snd_insert_protocol_fault.burst_length_nz)
      {
        req_read.burst_length = 0;
      }
      else if (egr_snd_insert_protocol_fault.max_burst_length)
      {
        req_read.burst_length = MAX_BURST_LENGTH + 1;
      }

      m_axis_egr_tx_req.write(req_read);
      req_read.direct = 0;
      egr_ctrl_queue.write(req_read);

      direct_priority = true; // invert priority
    }
    else
    {
      sessionReq req_read;
      direct_req.read_nb(req_read);

      // insert fault
      if (egr_snd_insert_protocol_fault.burst_length_nz)
      {
        req_read.burst_length = 0;
      }
      else if (egr_snd_insert_protocol_fault.max_burst_length)
      {
        req_read.burst_length = MAX_BURST_LENGTH + 1;
      }

      m_axis_egr_tx_req.write(req_read);
      req_read.direct = 1;
      egr_ctrl_queue.write(req_read);

      direct_priority = false; // invert priority
    }
  }
  else if (!s_axis_egr_rx_req.empty() &&
           direct_req.empty())
  {
    sessionReq req_read;
    s_axis_egr_rx_req.read_nb(req_read);

    // insert fault
    if (egr_snd_insert_protocol_fault.burst_length_nz)
    {
      req_read.burst_length = 0;
    }
    else if (egr_snd_insert_protocol_fault.max_burst_length)
    {
      req_read.burst_length = MAX_BURST_LENGTH + 1;
    }

    m_axis_egr_tx_req.write(req_read);
    req_read.direct = 0;
    egr_ctrl_queue.write(req_read);

    direct_priority = false; // clear priority
  }
  else if (s_axis_egr_rx_req.empty() &&
           !direct_req.empty())
  {
    sessionReq req_read;
    direct_req.read_nb(req_read);

    // insert fault
    if (egr_snd_insert_protocol_fault.burst_length_nz)
    {
      req_read.burst_length = 0;
    }
    else if (egr_snd_insert_protocol_fault.max_burst_length)
    {
      req_read.burst_length = MAX_BURST_LENGTH + 1;
    }

    m_axis_egr_tx_req.write(req_read);
    req_read.direct = 1;
    egr_ctrl_queue.write(req_read);

    direct_priority = false; // clear priority
  }
}

void egr_ctrl_resp(hls::stream<sessionReq> &s_axis_egr_tx_resp,
                   hls::stream<sessionReq> &direct_resp,
                   hls::stream<sessionReq> &egr_ctrl_queue,
                   hls::stream<sessionReq> &m_axis_egr_rx_resp,
                   hls::stream<sessionReq> &egr_trans_queue,
                   channelFrameCount &stat_egr_rcv_frame,
                   channelFrameCount &stat_egr_snd_frame,
                   faultProtocol &egr_rcv_insert_protocol_fault)
{
#pragma HLS pipeline II = 1

  static sessionReq direction;
  static bool direction_vld = false;

  if (direction_vld &&
      (direction.direct == 0) &&
      !s_axis_egr_tx_resp.empty())
  {
    // select function
    sessionReq read_resp;
    s_axis_egr_tx_resp.read_nb(read_resp);

    // insert fault
    if (egr_rcv_insert_protocol_fault.channel_eq)
    {
      read_resp.channel = ~read_resp.channel;
    }
    if (egr_rcv_insert_protocol_fault.burst_length_le)
    {
      read_resp.burst_length = MAX_BURST_LENGTH;
    }
    if (egr_rcv_insert_protocol_fault.sof_eq)
    {
      read_resp.sof = ~read_resp.sof;
    }
    if (egr_rcv_insert_protocol_fault.eof_eq)
    {
      read_resp.eof = ~read_resp.eof;
    }

    m_axis_egr_rx_resp.write(read_resp);
    read_resp.direct = direction.direct; // propagate direction
    egr_trans_queue.write(read_resp);

    if ((direction.sof == 1) && (read_resp.burst_length > 0))
    {
      stat_egr_rcv_frame = channelFrameCount(0, read_resp.channel);
      stat_egr_snd_frame = channelFrameCount(0, read_resp.channel);
    }

    direction_vld = false;
  }
  else if (direction_vld &&
           (direction.direct == 1) &&
           !s_axis_egr_tx_resp.empty())
  {
    // select direct transfer
    sessionReq read_resp;
    s_axis_egr_tx_resp.read_nb(read_resp);
    direct_resp.write(read_resp);
    read_resp.direct = direction.direct; // propagate direction
    egr_trans_queue.write(read_resp);

    if ((direction.sof == 1) && (read_resp.burst_length > 0))
    {
      stat_egr_snd_frame = channelFrameCount(0, read_resp.channel);
    }

    direction_vld = false;
  }
  else if (!direction_vld &&
           !egr_ctrl_queue.empty())
  {
    // dequeue next
    egr_ctrl_queue.read_nb(direction);
    direction_vld = true;
  }
}

void egr_trans(hls::stream<sessionReq> &egr_trans_queue,
               hls::stream<session_data_t> &s_axis_egr_rx_data,
               hls::stream<session_data_t> &direct_data,
               hls::stream<session_data_t> &m_axis_egr_tx_data,
               channelCycleDataCount &stat_egr_rcv_data,
               channelCycleDataCount &stat_egr_snd_data,
               faultProtocol &egr_snd_insert_protocol_fault)
{
#pragma HLS pipeline II = 1

  static uint32_t count_data = 0;
  static bool trans_read_vld = false;
  static sessionReq trans_read;

  // Count data
  if (!s_axis_egr_rx_data.empty() &&
      trans_read_vld &&
      trans_read.direct == 0)
  {
    // forward function data
    session_data_t trans_data;
    s_axis_egr_rx_data.read_nb(trans_data);
    m_axis_egr_tx_data.write(trans_data);

    if (count_data > 1)
    {
      stat_egr_rcv_data = channelCycleDataCount(0, trans_read.channel, TRANS_DATA_WIDTH_BYTES);
      stat_egr_snd_data = channelCycleDataCount(0, trans_read.channel, TRANS_DATA_WIDTH_BYTES);

      // decrement
      trans_read_vld = true;
      count_data--;
    }
    else
    {
      uint8_t bytenum = (trans_read.burst_length % TRANS_DATA_WIDTH_BYTES == 0) ? TRANS_DATA_WIDTH_BYTES : trans_read.burst_length % TRANS_DATA_WIDTH_BYTES;

      stat_egr_rcv_data = channelCycleDataCount(0, trans_read.channel, bytenum);
      stat_egr_snd_data = channelCycleDataCount(0, trans_read.channel, bytenum);

      // current transaction data end
      trans_read_vld = false;
      count_data = 0;
    }
  }
  else if (!direct_data.empty() &&
           trans_read_vld &&
           trans_read.direct == 1)
  {
    // forward direct data
    session_data_t trans_data;
    direct_data.read_nb(trans_data);
    m_axis_egr_tx_data.write(trans_data);

    if (count_data > 1)
    {
      stat_egr_snd_data = channelCycleDataCount(0, trans_read.channel, TRANS_DATA_WIDTH_BYTES);

      // decrement
      trans_read_vld = true;
      count_data--;
    }
    else
    {
      uint8_t bytenum = (trans_read.burst_length % TRANS_DATA_WIDTH_BYTES == 0) ? TRANS_DATA_WIDTH_BYTES : trans_read.burst_length % TRANS_DATA_WIDTH_BYTES;

      stat_egr_snd_data = channelCycleDataCount(0, trans_read.channel, bytenum);

      // current transaction data end
      trans_read_vld = false;
      count_data = 0;
    }
  }
  else if (!trans_read_vld &&
           !egr_trans_queue.empty())
  {
    egr_trans_queue.read_nb(trans_read);
    if (trans_read.burst_length > 0)
    {
      // current transaction set
      trans_read_vld = true;
      count_data = CDIV(trans_read.burst_length, TRANS_DATA_WIDTH_BYTES);
    }
    else
    {
      // current transaction data is empty
      trans_read_vld = false;
      count_data = 0;
    }
  }
}

void direct_trans_adaptor_core(hls::stream<sessionReq> &s_axis_ingr_rx_req,
                               hls::stream<sessionReq> &m_axis_ingr_rx_resp,
                               hls::stream<session_data_t> &s_axis_ingr_rx_data,
                               hls::stream<sessionReq> &m_axis_ingr_tx_req,
                               hls::stream<sessionReq> &s_axis_ingr_tx_resp,
                               hls::stream<session_data_t> &m_axis_ingr_tx_data,
                               hls::stream<sessionReq> &s_axis_egr_rx_req,
                               hls::stream<sessionReq> &m_axis_egr_rx_resp,
                               hls::stream<session_data_t> &s_axis_egr_rx_data,
                               hls::stream<sessionReq> &m_axis_egr_tx_req,
                               hls::stream<sessionReq> &s_axis_egr_tx_resp,
                               hls::stream<session_data_t> &m_axis_egr_tx_data,
                               channelFrameCount &stat_ingr_rcv_frame,
                               channelFrameCount &stat_ingr_snd_frame,
                               channelCycleDataCount &stat_ingr_rcv_data,
                               channelCycleDataCount &stat_ingr_snd_data,
                               channelFrameCount &stat_egr_rcv_frame,
                               channelFrameCount &stat_egr_snd_frame,
                               channelCycleDataCount &stat_egr_rcv_data,
                               channelCycleDataCount &stat_egr_snd_data,
                               faultProtocol &ingr_rcv_insert_protocol_fault,
                               faultProtocol &ingr_snd_insert_protocol_fault,
                               faultProtocol &egr_rcv_insert_protocol_fault,
                               faultProtocol &egr_snd_insert_protocol_fault)
{
#pragma HLS INTERFACE mode = axis port = s_axis_ingr_rx_req
#pragma HLS INTERFACE mode = axis port = m_axis_ingr_rx_resp
#pragma HLS INTERFACE mode = axis port = s_axis_ingr_rx_data
#pragma HLS INTERFACE mode = axis port = m_axis_ingr_tx_req
#pragma HLS INTERFACE mode = axis port = s_axis_ingr_tx_resp
#pragma HLS INTERFACE mode = axis port = m_axis_ingr_tx_data
#pragma HLS INTERFACE mode = axis port = s_axis_egr_rx_req
#pragma HLS INTERFACE mode = axis port = m_axis_egr_rx_resp
#pragma HLS INTERFACE mode = axis port = s_axis_egr_rx_data
#pragma HLS INTERFACE mode = axis port = m_axis_egr_tx_req
#pragma HLS INTERFACE mode = axis port = s_axis_egr_tx_resp
#pragma HLS INTERFACE mode = axis port = m_axis_egr_tx_data
#pragma HLS INTERFACE mode = ap_vld port = stat_ingr_rcv_frame
#pragma HLS INTERFACE mode = ap_vld port = stat_ingr_snd_frame
#pragma HLS INTERFACE mode = ap_vld port = stat_ingr_rcv_data
#pragma HLS INTERFACE mode = ap_vld port = stat_ingr_snd_data
#pragma HLS INTERFACE mode = ap_vld port = stat_egr_rcv_frame
#pragma HLS INTERFACE mode = ap_vld port = stat_egr_snd_frame
#pragma HLS INTERFACE mode = ap_vld port = stat_egr_rcv_data
#pragma HLS INTERFACE mode = ap_vld port = stat_egr_snd_data
#pragma HLS INTERFACE mode = ap_none port = ingr_rcv_insert_protocol_fault
#pragma HLS INTERFACE mode = ap_none port = ingr_snd_insert_protocol_fault
#pragma HLS INTERFACE mode = ap_none port = egr_rcv_insert_protocol_fault
#pragma HLS INTERFACE mode = ap_none port = egr_snd_insert_protocol_fault
#pragma HLS INTERFACE mode = ap_ctrl_none port = return

#pragma HLS dataflow disable_start_propagation

  // transaction queue
  hls::stream<sessionReq> direct_req;
#pragma HLS stream variable = direct_req depth = (INGR_OUTSTANDING_NUM + 1)
  hls::stream<sessionReq> direct_resp;
#pragma HLS stream variable = direct_resp depth = (INGR_OUTSTANDING_NUM + 1)
  hls::stream<session_data_t> direct_data;
#pragma HLS stream variable = direct_data depth = (MAX_BURST_LENGTH / TRANS_DATA_WIDTH_BYTES)
  hls::stream<sessionReq> ingr_ctrl_queue;
#pragma HLS stream variable = ingr_ctrl_queue depth = (INGR_OUTSTANDING_NUM + 1)
  hls::stream<sessionReq> ingr_trans_queue;
#pragma HLS stream variable = ingr_trans_queue depth = (INGR_OUTSTANDING_NUM + 1)
  hls::stream<sessionReq> egr_ctrl_queue;
#pragma HLS stream variable = egr_ctrl_queue depth = (EGR_OUTSTANDING_NUM + 1)
  hls::stream<sessionReq> egr_trans_queue;
#pragma HLS stream variable = egr_trans_queue depth = (EGR_OUTSTANDING_NUM + 1)

  ingr_ctrl_req(s_axis_ingr_rx_req,
                m_axis_ingr_tx_req,
                direct_req,
                ingr_ctrl_queue,
                ingr_snd_insert_protocol_fault);

  ingr_ctrl_resp(s_axis_ingr_tx_resp,
                 direct_resp,
                 ingr_ctrl_queue,
                 m_axis_ingr_rx_resp,
                 ingr_trans_queue,
                 stat_ingr_rcv_frame,
                 stat_ingr_snd_frame,
                 ingr_rcv_insert_protocol_fault);

  ingr_trans(ingr_trans_queue,
             s_axis_ingr_rx_data,
             m_axis_ingr_tx_data,
             direct_data,
             stat_ingr_rcv_data,
             stat_ingr_snd_data,
             ingr_snd_insert_protocol_fault);

  egr_ctrl_req(s_axis_egr_rx_req,
               direct_req,
               egr_ctrl_queue,
               m_axis_egr_tx_req,
               egr_snd_insert_protocol_fault);

  egr_ctrl_resp(s_axis_egr_tx_resp,
                direct_resp,
                egr_ctrl_queue,
                m_axis_egr_rx_resp,
                egr_trans_queue,
                stat_egr_rcv_frame,
                stat_egr_snd_frame,
                egr_rcv_insert_protocol_fault);

  egr_trans(egr_trans_queue,
            s_axis_egr_rx_data,
            direct_data,
            m_axis_egr_tx_data,
            stat_egr_rcv_data,
            stat_egr_snd_data,
            egr_snd_insert_protocol_fault);
}
