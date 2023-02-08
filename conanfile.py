from conans import ConanFile, tools


class NaoUbuntuConan(ConanFile):
    name = "nao-ubuntu"
    version = "2.0"
    settings = "os", "arch"
    description = "Minimal files to compile for Ubuntu on Nao"
    url = "https://github.com/NaoDevils/NaoImage"
    license = "None"
    author = "Aaron Larisch"
    topics = None

    def package(self):
        self.copy("*", "root-sdk/lib/x86_64-linux-gnu", "root-sdk/lib/x86_64-linux-gnu", symlinks=True)
        self.copy("*", "root-sdk/lib64", "root-sdk/lib64", symlinks=True)
        self.copy("*", "root-sdk/usr/include", "root-sdk/usr/include", symlinks=True)
        self.copy("*", "root-sdk/usr/lib/gcc", "root-sdk/usr/lib/gcc", symlinks=True)
        self.copy("*", "root-sdk/usr/lib/x86_64-linux-gnu", "root-sdk/usr/lib/x86_64-linux-gnu", symlinks=True)
        self.copy("ubuntu.toolchain.cmake", "root-sdk", "root-sdk", symlinks=True)
        
    def package_id(self):
        self.info.header_only()
