### 使用
1. 找到资源包中的`resource/contest_template`，打开此工程
2. 通过vivado的add source这里涉及到的所有文件，10个verilog文件，一个systemverilog文件
   添加完后v文件应该是在，在路径`contest_template/digital_twin.srcs/sources_1/imports/core`，注意模板的sv文件和这里的v文件在vivado中是可以混合编译的（mixed）
   sv文件如`Core_cpu.sv`应该是添加到`contest_template/digital_twin.srcs/sources_1/new`路径
3. 你可能需要生成一下ip，如果遇到ip里面的.v文件找不到的情况下，步骤如下123步
   ![image](https://github.com/user-attachments/assets/fe8f36bd-91bf-4af5-85d6-5ee885f755f3)
4. 模拟测试...
   
