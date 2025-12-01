
import torch
import torch.nn as nn
import math
# # from models.quant_layer import *
from models.quant_layer_project import *
# from vgg_quant import VGG_quant

cfg = {
    'VGG11': [64, 'M', 128, 'M', 256, 256, 'M', 512, 512, 'M', 512, 512, 'M'],
    'VGG13': [64, 64, 'M', 128, 128, 'M', 256, 256, 'M', 512, 512, 'M', 512, 512, 'M'],
    'VGG16_quant': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 512, 512, 512, 'M', 512, 512, 512, 'M'],
    # modified layers for project part2:
    'VGG16_quant_project': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 512, 512, 512, 'M', 512, 512, 512, 'M'],
    'VGG16': ['F', 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 512, 512, 512, 'M', 512, 512, 512, 'M'],
    'VGG19': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 256, 'M', 512, 512, 512, 512, 'M', 512, 512, 512, 512, 'M'],
}


class VGG_quant_project(nn.Module):
    def __init__(self, vgg_name):
        super(VGG_quant_project, self).__init__()
        self.features = self._make_layers(cfg[vgg_name])
        self.classifier = nn.Linear(512, 10)

    def forward(self, x):
        out = self.features(x)
        out = out.view(out.size(0), -1)
        out = self.classifier(out)
        return out

    def _make_layers(self, cfg):
        layers = []
        in_channels = 3
        for x in cfg:
            if x == 'M':
                layers += [nn.MaxPool2d(kernel_size=2, stride=2)]
            elif x == 'F':  # This is for the 1st layer
                layers += [nn.Conv2d(in_channels, 64, kernel_size=3, padding=1, bias=False),
                           nn.BatchNorm2d(64),
                           nn.ReLU(inplace=True)]
                in_channels = 64
            else:
                layers += [QuantConv2d_project_part2(in_channels, x, kernel_size=3, padding=1),
                           nn.BatchNorm2d(x),
                           nn.ReLU(inplace=True)]
                in_channels = x
        layers += [nn.AvgPool2d(kernel_size=1, stride=1)]

        # layer modifications for part2
        layers[24] = QuantConv2d_project_part2(256, 16, kernel_size=3, padding=1)
        layers[25] = nn.BatchNorm2d(16)
        layers[26] = nn.ReLU(inplace=True)
        # modified layer:
        layers[27] = QuantConv2d_project_part2(16, 16, kernel_size=3, padding=1)
        # model.features[28] = nn.BatchNorm2d(16)
        # layers[28] = nn.ReLU(inplace=False) # two relus will have the same result, hcene we'll have removed the batchnorm layer
        layers[28] = nn.Identity()
        layers[29] = nn.ReLU(inplace=True)
        
        layers[30] = QuantConv2d_project_part2(16, 512, kernel_size=3, padding=1)
        layers[31] = nn.BatchNorm2d(512)
        
        return nn.Sequential(*layers)

    def show_params(self):
        for m in self.modules():
            if isinstance(m, QuantConv2d):
                m.show_params()
    

def VGG16_quant_project(**kwargs):
    model = VGG_quant_project(vgg_name = 'VGG16_quant', **kwargs)
    return model



