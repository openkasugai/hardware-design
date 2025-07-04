#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

import sys
import create_function_wrapper as cfw

class FunctionCtrlWrapper:

    _template_file = 'function_ctrl_wrapper_template.v'
    _params = {}
    _binds = {}
    _unbound_signals = []
    _template_strings = []
    _wrapper_strings = []
    _wire_signals = []

    _NORMAL = 0
    _GENERATE = 1
    _AGGREGATE = 2
    _PARAMETER = 3
    _ADD = 4
    _CONVERT = 5
    _GENERATE_UNBOUND = 6

    _func_wrapper = None
    _input_port_num = 'IPORT_NUM'
    _output_port_num = 'OPORT_NUM'

    @classmethod
    def ParseArgs(cls, argv):
        params = {}
        binds = {}
        mode = ''
        template_file = ''
        verbose = False
        output_file = None
        func_file = None
        for arg in argv[1:]:
            if arg == '-t' or arg == '--template':
                mode = 'template'
            elif arg == '-f' or arg == '--func':
                mode = 'func'
            elif arg == '-v' or arg == '--verbose':
                verbose = True
            elif arg == '-o' or arg == '--output':
                mode = 'output'
            elif arg.find('--') == 0:
                eq_pos = arg.find('=')
                if eq_pos > 0:
                    params[arg[2:eq_pos]] = arg[eq_pos+1:]
                else:
                    mode = arg[2:]
            elif mode == '':
                raise ValueError('arg parse')
            elif mode == 'template':
                template_file = arg
                mode = ''
            elif mode == 'output':
                output_file = arg
                mode = ''
            elif mode == 'func':
                func_file = arg
                mode = ''
            elif mode == 'bind':
                eq_pos = arg.find('=')
                if eq_pos > 0:
                    binds[arg[:eq_pos]] = arg[eq_pos+1:]
                mode = ''
            else:
                params[mode] = arg
                mode = ''
        return params, binds, template_file, output_file, func_file, verbose

    def __init__(self, param_arg, binds, template):
        self._params = param_arg
        self._binds = binds
        self._template_file = template

    def SetFunctionWrapper(self, wrapper):
        self._func_wrapper = wrapper
        module_name = wrapper.GetModuleName()
        self._params['module_name'] = module_name

    def LoadTemplate(self):
        with open(self._template_file) as f:
            self._template_strings = f.readlines()

    def Extract(self):
        mode = self._NORMAL
        mode_params = []
        for line in self._template_strings:
            comment_pos = line.find('//')
            if comment_pos >= 0:
                command = line[comment_pos+2:].rstrip().split(' ')
                is_start = command[0] == 'start'
                is_end = command[0] == 'end'
                if is_start or is_end:
                    if mode != self._NORMAL and is_start:
                        raise ValueError('wrong start')
                    if mode == self._NORMAL and is_end:
                        raise ValueError('wrong end')
                    if is_start:
                        print(command)
                        if command[1] == 'generate':
                            mode = self._GENERATE
                            if command[3] in self._params:
                                param_value = self._params[command[3]]
                            else:
                                raise ValueError('param not found')
                            mode_params = [command[2], param_value]
                            continue
                        if command[1] == 'generate_unbound':
                            mode = self._GENERATE_UNBOUND
                            if command[3] in self._params:
                                param_value = self._params[command[3]]
                            else:
                                raise ValueError('param not found')
                            mode_params = [command[2], param_value]
                            continue
                        if command[1] == 'aggregate':
                            mode = self._AGGREGATE
                            if command[3] in self._params:
                                param_value = self._params[command[3]]
                            else:
                                raise ValueError('param not found')
                            mode_params = [command[2], param_value]
                            continue
                        if command[1] == 'parameter':
                            mode = self._PARAMETER
                            continue
                        if command[1] == 'convert':
                            mode = self._CONVERT
                            mode_params = command[2:]
                            continue
                        if command[1] == 'add':
                            mode = self._ADD
                            if command[2] == 'interfaces':
                                self.add_interfaces()
                            elif command[2] == 'function':
                                self.add_function()
                            continue
                    if is_end:
                        mode = self._NORMAL
                        mode_params = []
                        continue
            if mode == self._GENERATE:
                self.generate(mode_params, line)
            elif mode == self._GENERATE_UNBOUND:
                self.generate(mode_params, line)
                self.add_unbound(mode_params, line)
            elif mode == self._AGGREGATE:
                self.aggregate(mode_params, line)
            elif mode == self._PARAMETER:
                self.parameter(line)
            elif mode == self._CONVERT:
                self.convert(mode_params, line)
            else:
                self._wrapper_strings.append(line)

    def Output(self, filename = None):
        if filename is None:
            filename = './function_ctrl_wrapper.v'
        with open(filename, mode='w') as f:
            f.writelines(self._wrapper_strings)

    def generate(self, mode_params, line):
        tokens = line.strip().split(' ')
        if line.find(' wire ') > 0 or line.find('wire ') == 0:
            for idx in range(0, len(tokens)):
                if mode_params[0] in tokens[idx]:
                    if not tokens[idx] in self._wire_signals:
                        self._wire_signals.append(tokens[idx].replace(';',''))
        num = int(mode_params[1])
        for idx in range(0,num):
            mod_line = line.replace(mode_params[0], str(idx))
            self._wrapper_strings.append(mod_line)

    def add_unbound(self, mode_params, line):
        tokens = line.strip().split(' ')
        if line.find(' wire ') > 0 or line.find('wire ') == 0:
            for idx in range(0, len(tokens)):
                if mode_params[0] in tokens[idx]:
                    num = int(mode_params[1])
                    for idx2 in range(0,num):
                        mod_name = tokens[idx].replace(mode_params[0], str(idx2))
                        if not mod_name in self._unbound_signals:
                            self._unbound_signals.append(mod_name.replace(';',''))

    def aggregate(self, mode_params, line):
        num = int(mode_params[1])
        tokens = line.split(' ')
        agg_idx = -1
        for idx in range(0,len(tokens)):
            if tokens[idx].find(mode_params[0]) >= 0:
                agg_idx = idx
                break
        if agg_idx >= 0:
            agg_string = ''
            if num > 1:
                agg_string = '}'
            for idx in range(0, num):
                agg_string = tokens[agg_idx].replace(mode_params[0], str(idx)) + agg_string
                if idx < num-1:
                    agg_string = ', ' + agg_string
            if num > 1:
                agg_string = '{' + agg_string
            mod_line = line.replace(tokens[agg_idx], agg_string)
            self._wrapper_strings.append(mod_line)

    def parameter(self, line):
        mod_line = line.replace('=', ' = ')
        mod_line = mod_line.replace('  ', ' ')
        tokens = mod_line.strip().split(' ')
        eq_idx = -1
        for idx in range(0, len(tokens)):
            if tokens[idx] == '=':
                eq_idx = idx
                break
        if eq_idx > 0:
            param_name = tokens[eq_idx-1]
            if param_name in self._params:
                mod_line = line.replace(tokens[eq_idx+1], self._params[param_name] + ';')
            else:
                mod_line = line
        self._wrapper_strings.append(mod_line)

    def convert(self, mode_params, line):
        if mode_params[1] in self._params:
            mod_line = line.replace(mode_params[0], self._params[mode_params[1]])
        else:
            mod_line = line
        self._wrapper_strings.append(mod_line)

    def add_interfaces(self):
        if self._func_wrapper is None:
            return
        axi_slaves, axi_masters = self._func_wrapper.GetAxi()
        bundles, unbundles = self._func_wrapper.GetBundles()
        signals = []
        ports = []
        ports.extend(axi_slaves)
        ports.extend(axi_masters)
        for port in ports:
            cur_bundle = bundles[port]
            for sig in cur_bundle:
                sig_name = cur_bundle[sig]
                signals.append(sig_name)
        signals.extend(unbundles)
        inputs, outputs = self._func_wrapper.GetInout()
        for sig in signals:
            if sig in inputs:
                signal_decl = 'input'
                signal_width = inputs[sig]
            elif sig in outputs:
                signal_decl = 'output'
                signal_width = outputs[sig]
            else:
                raise ValueError('no signal name found: ' + sig)
            if len(signal_width) > 0:
                signal_decl += ' ' + signal_width + ' '
            else:
                signal_decl += ' '
            signal_decl += sig + ',\n'
            self._wrapper_strings.append(signal_decl)

    def add_function(self):
        if self._func_wrapper is None:
            return
        axis_inputs, axis_outputs = self._func_wrapper.GetAxis()
        bundles, unbundles = self._func_wrapper.GetBundles()
        inputs, outputs = self._func_wrapper.GetInout()
        binds = self._func_wrapper.GetBinds()
        global_signals = self._func_wrapper.GetGlobals()
        module_name = self._func_wrapper.GetModuleName()
        indent = ' ' * 4
        self._wrapper_strings.append(indent + module_name + ' ' + module_name + ' (\n')
        idx = 0
        for port in axis_inputs:
            self.add_bundle_port(bundles[port], True, True, idx, indent*2)
            idx += 1
        idx = 0
        for port in axis_outputs:
            self.add_bundle_port(bundles[port], True, False, idx, indent*2)
            idx += 1
        for port in bundles:
            if port in axis_inputs or port in axis_outputs:
                continue
            self.add_bundle_port(bundles[port], False, False, None, indent*2)
        for port in binds:
            self.add_bind_port(port, binds[port], indent*2)
        keys = list(global_signals.keys())
        for idx in range(0, len(global_signals)):
            sig = keys[idx]
            self.add_global_signal(sig, global_signals[sig], idx == len(global_signals)-1, indent*2)
        self._wrapper_strings.append(indent + ');\n')
        self.add_other_binds()

    def add_bind_port(self, port, bind_port, indent):
        port_link = '.' + port + ' ( ' + bind_port + ' ),'
        self._wrapper_strings.append(indent + port_link + '\n')

    def add_bundle_port(self, bundle, is_axis, is_input, idx, indent):
        for sig in bundle:
            port_link = '.' + bundle[sig] + ' ( '
            if is_axis and is_input:
                num_identify = self._input_port_num
            elif is_axis and not is_input:
                num_identify = self._output_port_num
            else:
                num_identify = ''
            if num_identify == '':
                port_link += bundle[sig] + ' ),'
            else:
                found = False
                for wire in self._wire_signals:
                    if wire.find(num_identify) > 0 and wire.find(sig) > 0:
                        port_link += wire.replace(num_identify, str(idx)) + ' ),'
                        found = True
                        break
                if not found:
                    port_link += ' ),'
            self._wrapper_strings.append(indent + port_link + '\n')

    def add_global_signal(self, sig, sig_name, is_last, indent):
        port_link = '.' + sig_name + ' ( ' + sig + ')'
        if not is_last:
            port_link += ','
        self._wrapper_strings.append(indent + port_link + '\n')

    def add_other_binds(self):
        print(self._unbound_signals)
        print(self._binds)
        for sig in self._unbound_signals:
            if sig in self._binds:
                self._wrapper_strings.append(' '*4 + 'assign ' + sig + ' = ' + self._binds[sig] + ';\n')

if __name__ == "__main__":

    params, binds, template, output, func, verbose = FunctionCtrlWrapper.ParseArgs(sys.argv)
    func_wrapper = cfw.FunctionWrapper()
    wrapper = FunctionCtrlWrapper(params, binds, template)
    if func is not None:
        func_wrapper.Analyze(func)
        for key in binds:
            if not func_wrapper.AddBind(key, binds[key]):
                print(f'{key} cannot binds to {binds[key]}')
        axis_inputs, axis_outputs = func_wrapper.GetAxis()
        axi_slaves, axi_masters = func_wrapper.GetAxi()
        if len(axi_masters) == 0 and 'IPORT_NUM' in params:
            if int(params['IPORT_NUM']) != len(axis_inputs):
                raise ValueError('IPORT_NUM is wrong for the function')
        elif len(axi_masters) == 0 and 'OPORT_NUM' in params:
            if int(params['OPORT_NUM']) != len(axis_outputs):
                raise ValueError('OPORT_NUM is wrong for the function')
        wrapper.SetFunctionWrapper(func_wrapper)
        if verbose:
            print('axis input : ', axis_inputs)
            print('axis output: ', axis_outputs)
            print('axi slaves : ', axi_slaves)
            print('axi masters: ', axi_masters)
            bundles, unbundles = func_wrapper.GetBundles()
            print('bundle     : ', bundles)
            print('unbundle   : ', unbundles)

    wrapper.LoadTemplate()
    wrapper.Extract()
    wrapper.Output(output)
