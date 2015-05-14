//
//  MyBlobDetector.h
//  ioscv
//
//  Created by Ofer Livny on 5/14/15.
//  Copyright (c) 2015 Ofer Livny. All rights reserved.
//

#ifndef ioscv_MyBlobDetector_h
#define ioscv_MyBlobDetector_h

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#endif

// My implementation of blob detector, supports configurable binarization polarity

class MySimpleBlobDetector: public cv::SimpleBlobDetector {
public:
    MySimpleBlobDetector(cv::SimpleBlobDetector::Params params) : SimpleBlobDetector(params){
        polarity = CV_THRESH_BINARY_INV;
    };
    void setPolarity(int p) {polarity=p;}
protected:
    int polarity;
    void detectImpl(const cv::Mat& image, std::vector<cv::KeyPoint>& keypoints, const cv::Mat&) const
    {
        //TODO: support mask
        keypoints.clear();
        cv::Mat grayscaleImage;
        if (image.channels() == 3)
            cvtColor(image, grayscaleImage, CV_BGR2GRAY);
        else
            grayscaleImage = image;
        
        if (grayscaleImage.type() != CV_8UC1){
            CV_Error(CV_StsUnsupportedFormat, "Blob detector only supports 8-bit images!");
        }
        std::vector < std::vector<Center> > centers;
        for (double thresh = params.minThreshold; thresh < params.maxThreshold; thresh += params.thresholdStep)
        {
            cv::Mat binarizedImage;
            threshold(grayscaleImage, binarizedImage, thresh, 255, polarity);
            
            
            std::vector < Center > curCenters;
            findBlobs(grayscaleImage, binarizedImage, curCenters);
            std::vector < std::vector<Center> > newCenters;
            for (size_t i = 0; i < curCenters.size(); i++)
            {
#ifdef DEBUG_BLOB_DETECTOR
                //      circle(keypointsImage, curCenters[i].location, curCenters[i].radius, Scalar(0,0,255),-1);
#endif
                
                bool isNew = true;
                for (size_t j = 0; j < centers.size(); j++)
                {
                    double dist = norm(centers[j][ centers[j].size() / 2 ].location - curCenters[i].location);
                    isNew = dist >= params.minDistBetweenBlobs && dist >= centers[j][ centers[j].size() / 2 ].radius && dist >= curCenters[i].radius;
                    if (!isNew)
                    {
                        centers[j].push_back(curCenters[i]);
                        
                        size_t k = centers[j].size() - 1;
                        while( k > 0 && centers[j][k].radius < centers[j][k-1].radius )
                        {
                            centers[j][k] = centers[j][k-1];
                            k--;
                        }
                        centers[j][k] = curCenters[i];
                        
                        break;
                    }
                }
                if (isNew)
                {
                    newCenters.push_back(std::vector<Center> (1, curCenters[i]));
                    //centers.push_back(vector<Center> (1, curCenters[i]));
                }
            }
            std::copy(newCenters.begin(), newCenters.end(), std::back_inserter(centers));
        }
        
        for (size_t i = 0; i < centers.size(); i++)
        {
            if (centers[i].size() < params.minRepeatability)
                continue;
            cv::Point2d sumPoint(0, 0);
            double normalizer = 0;
            for (size_t j = 0; j < centers[i].size(); j++)
            {
                sumPoint += centers[i][j].confidence * centers[i][j].location;
                normalizer += centers[i][j].confidence;
            }
            sumPoint *= (1. / normalizer);
            cv::KeyPoint kpt(sumPoint, (float)(centers[i][centers[i].size() / 2].radius));
            keypoints.push_back(kpt);
        }
        

    }
};
#endif
